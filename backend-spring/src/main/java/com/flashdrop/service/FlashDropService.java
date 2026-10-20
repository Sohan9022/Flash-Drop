package com.flashdrop.service;

import com.flashdrop.dto.*;
import com.flashdrop.model.*;
import com.flashdrop.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;

@Service
public class FlashDropService {

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private DropRepository dropRepository;

    @Autowired
    private CartReservationRepository reservationRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private OrderLogRepository orderLogRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    /**
     * PESSIMISTIC LOCKING RESERVATION ENGINE (REST Entrypoint)
     * Acquires exclusive row lock (FOR UPDATE), enforces drop active state,
     * checks stock boundaries, and creates temporary 5-minute hold.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ReservationResponse reserveProduct(Long userId, Long productId, int quantity) {
        return reserveProductInternal(userId, productId, quantity);
    }

    /**
     * Internal atomic reservation logic executed inside an active transaction.
     */
    public ReservationResponse reserveProductInternal(Long userId, Long productId, int quantity) {
        if (quantity <= 0) {
            return new ReservationResponse(null, "INVALID_QUANTITY", "Quantity must be greater than zero.");
        }

        // 1. SELECT ... FOR UPDATE (Row-Level Lock)
        Optional<Product> optionalProduct = productRepository.findByIdWithPessimisticLock(productId);
        if (optionalProduct.isEmpty()) {
            return new ReservationResponse(null, "PRODUCT_NOT_FOUND", "Product does not exist.");
        }

        Product product = optionalProduct.get();

        // 2. Validate Drop Lifecycle State (Must be ACTIVE)
        if (product.getDropId() != null) {
            Optional<Drop> optionalDrop = dropRepository.findById(product.getDropId());
            if (optionalDrop.isPresent()) {
                Drop drop = optionalDrop.get();
                if (!"ACTIVE".equalsIgnoreCase(drop.getStatus())) {
                    return new ReservationResponse(
                            null,
                            "DROP_NOT_ACTIVE",
                            "Cannot purchase yet. Drop status is currently: " + drop.getStatus()
                    );
                }
            }
        }

        // 3. Verify Stock Availability
        if (product.getAvailableStock() < quantity) {
            return new ReservationResponse(null, "OUT_OF_STOCK", "Sold out! Remaining units: " + product.getAvailableStock());
        }

        // 4. Decrement live stock
        product.setAvailableStock(product.getAvailableStock() - quantity);
        productRepository.save(product);

        // 5. Create 5-minute reservation hold
        CartReservation reservation = new CartReservation(
                userId,
                productId,
                quantity,
                "HELD",
                LocalDateTime.now().plusMinutes(5)
        );
        reservation = reservationRepository.save(reservation);

        return new ReservationResponse(
                reservation.getReservationId(),
                "SUCCESS",
                "Stock reserved successfully for 5 minutes. Proceed to checkout."
        );
    }

    /**
     * ATOMIC CHECKOUT TRANSACTION
     * Converts an active HELD reservation into a finalized Order and OrderItem.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public CheckoutResponse completeCheckout(Long userId, Long reservationId) {
        Optional<CartReservation> optionalRes = reservationRepository.findByIdWithLock(reservationId);
        if (optionalRes.isEmpty()) {
            return new CheckoutResponse(null, "RESERVATION_NOT_FOUND", "Reservation does not exist.");
        }

        CartReservation res = optionalRes.get();

        if (!res.getUserId().equals(userId)) {
            return new CheckoutResponse(null, "UNAUTHORIZED", "Reservation belongs to a different buyer.");
        }

        if (!"HELD".equals(res.getStatus())) {
            return new CheckoutResponse(null, "INVALID_STATUS", "Reservation is already " + res.getStatus());
        }

        if (res.getExpiresAt().isBefore(LocalDateTime.now())) {
            // Expired hold - return stock to available inventory
            res.setStatus("EXPIRED");
            reservationRepository.save(res);

            productRepository.findByIdWithPessimisticLock(res.getProductId()).ifPresent(prod -> {
                prod.setAvailableStock(prod.getAvailableStock() + res.getQuantity());
                productRepository.save(prod);
            });

            return new CheckoutResponse(null, "EXPIRED", "Your 5-minute reservation expired.");
        }

        Product product = productRepository.findById(res.getProductId()).orElse(null);
        if (product == null) {
            return new CheckoutResponse(null, "PRODUCT_NOT_FOUND", "Associated product could not be located.");
        }

        BigDecimal unitPrice = product.getPrice();
        BigDecimal total = unitPrice.multiply(BigDecimal.valueOf(res.getQuantity()));

        // 1. Create Order (Database trigger trg_order_audit_trail logs this)
        Order order = new Order(userId, total, "COMPLETED");
        order = orderRepository.save(order);

        // 2. Create Order Line Items
        OrderItem item = new OrderItem(order.getOrderId(), res.getProductId(), res.getQuantity(), unitPrice);
        orderItemRepository.save(item);

        // 3. Mark reservation as checked out
        res.setStatus("CHECKED_OUT");
        reservationRepository.save(res);

        return new CheckoutResponse(order.getOrderId(), "SUCCESS", "Order placed successfully!");
    }

    /**
     * SWEEPER: Reclaims unpurchased stock from expired reservations with pessimistic locking
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public int sweepExpiredReservations() {
        List<CartReservation> expiredList = reservationRepository.findExpiredWithLock("HELD", LocalDateTime.now());
        int count = 0;

        for (CartReservation res : expiredList) {
            res.setStatus("EXPIRED");
            reservationRepository.save(res);

            productRepository.findByIdWithPessimisticLock(res.getProductId()).ifPresent(p -> {
                p.setAvailableStock(p.getAvailableStock() + res.getQuantity());
                productRepository.save(p);
            });
            count++;
        }
        return count;
    }

    /**
     * HIGH CONCURRENCY STRESS SIMULATION
     * Uses TransactionTemplate per asynchronous thread to guarantee proper transaction boundaries
     * and row locks across the worker thread pool without Spring AOP self-invocation issues.
     */
    public Map<String, Object> simulateDrop(Long productId, int buyers) {
        Product initialProd = productRepository.findById(productId).orElse(null);
        int initialStock = initialProd != null ? initialProd.getAvailableStock() : 0;

        ExecutorService executor = Executors.newFixedThreadPool(Math.min(buyers, 50));
        List<CompletableFuture<Map<String, Object>>> futures = new ArrayList<>();

        long startTime = System.currentTimeMillis();

        for (int i = 0; i < buyers; i++) {
            final int threadId = i + 1;
            final long userId = (i % 5) + 1;

            CompletableFuture<Map<String, Object>> future = CompletableFuture.supplyAsync(() -> {
                // Programmatic transaction boundary per worker thread
                TransactionTemplate txTemplate = new TransactionTemplate(transactionManager);
                txTemplate.setIsolationLevel(TransactionDefinition.ISOLATION_READ_COMMITTED);

                ReservationResponse res = txTemplate.execute(status ->
                        reserveProductInternal(userId, productId, 1)
                );

                Map<String, Object> result = new HashMap<>();
                result.put("thread", threadId);
                result.put("userId", userId);
                result.put("resId", res != null ? res.getReservationId() : null);
                result.put("status", res != null ? res.getStatus() : "ERROR");
                result.put("message", res != null ? res.getMessage() : "Unknown error");
                return result;
            }, executor);

            futures.add(future);
        }

        List<Map<String, Object>> results = futures.stream().map(CompletableFuture::join).toList();
        executor.shutdown();

        double elapsed = (System.currentTimeMillis() - startTime) / 1000.0;
        Product finalProd = productRepository.findById(productId).orElse(null);
        int finalStock = finalProd != null ? finalProd.getAvailableStock() : 0;

        long successes = results.stream().filter(r -> "SUCCESS".equals(r.get("status"))).count();
        long outOfStock = results.stream().filter(r -> "OUT_OF_STOCK".equals(r.get("status"))).count();

        Map<String, Object> response = new HashMap<>();
        response.put("initialStock", initialStock);
        response.put("finalStock", finalStock);
        response.put("buyersCount", buyers);
        response.put("elapsed", String.format("%.2f", elapsed));
        response.put("successCount", successes);
        response.put("outOfStockCount", outOfStock);
        response.put("results", results);

        return response;
    }

    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    public List<OrderLog> getLatestLogs() {
        return orderLogRepository.findTop20ByOrderByLogIdDesc();
    }

    public List<Map<String, Object>> getTrendingProducts() {
        return jdbcTemplate.queryForList("SELECT * FROM v_trending_products");
    }
}
