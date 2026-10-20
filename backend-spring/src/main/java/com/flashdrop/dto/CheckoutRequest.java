package com.flashdrop.dto;

public class CheckoutRequest {
    private Long userId;
    private Long reservationId;

    public CheckoutRequest() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public Long getReservationId() { return reservationId; }
    public void setReservationId(Long reservationId) { this.reservationId = reservationId; }
}
