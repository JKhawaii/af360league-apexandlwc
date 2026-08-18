import { LightningElement, api } from 'lwc';

export default class ReplenishmentProductCard extends LightningElement {
  @api product;
  @api selected = false;
  @api quantity = 1;
  imageAvailable = true;

  get hasImage() {
    return Boolean(this.product?.imageUrl && this.imageAvailable);
  }

  get formattedPrice() {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(Number(this.product?.unitPrice) || 0);
  }

  get stockStatus() {
    const current = Number(this.product?.currentStock) || 0;
    const safety = Number(this.product?.safetyStock) || 0;
    return current <= safety ? 'Below safety stock' : 'Stock available';
  }

  get stockClass() {
    const current = Number(this.product?.currentStock) || 0;
    const safety = Number(this.product?.safetyStock) || 0;
    return current <= safety ? 'stock stock_low' : 'stock';
  }

  get checkboxLabel() {
    return `Select ${this.product?.name || 'product'}`;
  }

  get quantityLabel() {
    return `Order quantity for ${this.product?.name || 'product'}`;
  }

  handleSelection(event) {
    const selected = event.target.checked;
    this.dispatchEvent(
      new CustomEvent('selectionchange', {
        bubbles: true,
        composed: true,
        detail: {
          selected,
          product: {
            ...this.product,
            quantity:
              Number(this.quantity) || this.product.defaultOrderQuantity || 1
          }
        }
      })
    );
  }

  handleQuantity(event) {
    const quantity = Math.max(1, Math.floor(Number(event.detail.value) || 1));
    event.target.value = quantity;
    this.dispatchEvent(
      new CustomEvent('quantitychange', {
        bubbles: true,
        composed: true,
        detail: {
          productId: this.product.productId,
          quantity
        }
      })
    );
  }

  handleImageError() {
    this.imageAvailable = false;
  }
}