package com.flashdrop.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "order_logs")
public class OrderLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id")
    private Long logId;

    @Column(name = "order_id", nullable = false)
    private Long orderId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false, length = 50)
    private String action;

    @Column(columnDefinition = "TEXT")
    private String details;

    @Column(name = "logged_at", insertable = false, updatable = false)
    private LocalDateTime loggedAt;

    public OrderLog() {}

    public Long getLogId() { return logId; }
    public Long getOrderId() { return orderId; }
    public Long getUserId() { return userId; }
    public String getAction() { return action; }
    public String getDetails() { return details; }
    public LocalDateTime getLoggedAt() { return loggedAt; }
}
