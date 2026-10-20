package com.flashdrop.controller;

import com.flashdrop.dto.*;
import com.flashdrop.model.*;
import com.flashdrop.service.FlashDropService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class FlashDropController {

    @Autowired
    private FlashDropService flashDropService;

    @GetMapping("/products")
    public ResponseEntity<List<Product>> getProducts() {
        return ResponseEntity.ok(flashDropService.getAllProducts());
    }

    @PostMapping("/reserve")
    public ResponseEntity<ReservationResponse> reserve(@RequestBody ReservationRequest request) {
        ReservationResponse response = flashDropService.reserveProduct(
                request.getUserId(),
                request.getProductId(),
                request.getQuantity()
        );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/checkout")
    public ResponseEntity<CheckoutResponse> checkout(@RequestBody CheckoutRequest request) {
        CheckoutResponse response = flashDropService.completeCheckout(
                request.getUserId(),
                request.getReservationId()
        );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/simulate-drop")
    public ResponseEntity<Map<String, Object>> simulate(@RequestBody Map<String, Object> body) {
        Long productId = Long.valueOf(body.getOrDefault("productId", 1).toString());
        int buyers = Integer.parseInt(body.getOrDefault("buyers", 20).toString());

        Map<String, Object> simulationResult = flashDropService.simulateDrop(productId, buyers);
        return ResponseEntity.ok(simulationResult);
    }

    @GetMapping("/logs")
    public ResponseEntity<List<OrderLog>> getLogs() {
        return ResponseEntity.ok(flashDropService.getLatestLogs());
    }

    @GetMapping("/views/trending")
    public ResponseEntity<List<Map<String, Object>>> getTrending() {
        return ResponseEntity.ok(flashDropService.getTrendingProducts());
    }

    @PostMapping("/sweep")
    public ResponseEntity<Map<String, Object>> sweep() {
        int swept = flashDropService.sweepExpiredReservations();
        Map<String, Object> res = new HashMap<>();
        res.put("sweptCount", swept);
        return ResponseEntity.ok(res);
    }
}
