package com.flashdrop.dto;

public class ReservationResponse {
    private Long reservationId;
    private String status;
    private String message;

    public ReservationResponse() {}

    public ReservationResponse(Long reservationId, String status, String message) {
        this.reservationId = reservationId;
        this.status = status;
        this.message = message;
    }

    public Long getReservationId() { return reservationId; }
    public void setReservationId(Long reservationId) { this.reservationId = reservationId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
