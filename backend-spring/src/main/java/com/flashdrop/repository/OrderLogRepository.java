package com.flashdrop.repository;

import com.flashdrop.model.OrderLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OrderLogRepository extends JpaRepository<OrderLog, Long> {
    List<OrderLog> findTop20ByOrderByLogIdDesc();
}
