package com.flashdrop.dto;

public class ReservationRequest {
    private Long userId;
    private Long productId;
    private Integer quantity = 1;

    public ReservationRequest() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public Integer getQuantity() { return quantity != null ? quantity : 1; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }
}
