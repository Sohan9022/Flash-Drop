package com.flashdrop.repository;

import com.flashdrop.model.CartReservation;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface CartReservationRepository extends JpaRepository<CartReservation, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT r FROM CartReservation r WHERE r.reservationId = :id")
    Optional<CartReservation> findByIdWithLock(@Param("id") Long id);

    List<CartReservation> findByStatusAndExpiresAtBefore(String status, LocalDateTime time);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT r FROM CartReservation r WHERE r.status = :status AND r.expiresAt < :time ORDER BY r.productId ASC, r.reservationId ASC")
    List<CartReservation> findExpiredWithLock(@Param("status") String status, @Param("time") LocalDateTime time);
}
