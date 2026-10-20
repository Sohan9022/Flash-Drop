package com.flashdrop.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "drops")
public class Drop {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "drop_id")
    private Long dropId;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "drop_start_time", nullable = false)
    private LocalDateTime dropStartTime;

    @Column(name = "drop_end_time", nullable = false)
    private LocalDateTime dropEndTime;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    public Drop() {}

    public Long getDropId() { return dropId; }
    public void setDropId(Long dropId) { this.dropId = dropId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public LocalDateTime getDropStartTime() { return dropStartTime; }
    public void setDropStartTime(LocalDateTime dropStartTime) { this.dropStartTime = dropStartTime; }

    public LocalDateTime getDropEndTime() { return dropEndTime; }
    public void setDropEndTime(LocalDateTime dropEndTime) { this.dropEndTime = dropEndTime; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
}
