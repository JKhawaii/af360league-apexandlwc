import { LightningElement, api } from 'lwc';
import { fromContext } from '@lwc/state';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { open, execute } from 'lightning/accApi';
import createReplenishmentOrder from '@salesforce/apex/ReplenishmentController.createReplenishmentOrder';
import createReplenishmentState from 'c/replenishmentStateManager';

export default class ReplenishmentWizardStep3 extends NavigationMixin(
  LightningElement
) {
  @api botId;
  replenishmentState = fromContext(createReplenishmentState);
  isCreating = false;
  isAskingAgent = false;
  orderId;
  orderNumber;
  errorMessage;

  get storeName() {
    return this.replenishmentState.value.storeName;
  }

  get storeType() {
    return this.replenishmentState.value.storeType;
  }

  get orderDate() {
    return this.replenishmentState.value.orderDate;
  }

  get formattedOrderDate() {
    if (!this.orderDate) {
      return '';
    }
    const [year, month, day] = this.orderDate.split('-').map(Number);
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'short',
      day: '2-digit'
    }).format(new Date(year, month - 1, day));
  }

  get productCount() {
    return this.replenishmentState.value.productCount;
  }

  get totalUnits() {
    return this.replenishmentState.value.totalUnits;
  }

  get estimatedTotal() {
    return this.replenishmentState.value.estimatedTotal;
  }

  get chosenProducts() {
    return this.replenishmentState.value.chosenProducts.map((product) => ({
      ...product,
      lineTotal:
        (Number(product.quantity) || 0) * (Number(product.unitPrice) || 0)
    }));
  }

  get orderNotes() {
    return this.replenishmentState.value.orderNotes;
  }

  get createDisabled() {
    return this.isCreating || !this.replenishmentState.value.canCreateOrder;
  }

  get hasOrder() {
    return Boolean(this.orderId);
  }

  get askAgentDisabled() {
    return this.isAskingAgent || !this.botId;
  }

  handleNotesChange(event) {
    this.replenishmentState.value.setOrderNotes(event.detail.value);
  }

  async handleCreateOrder() {
    if (this.createDisabled) {
      return;
    }
    this.isCreating = true;
    this.errorMessage = undefined;
    const state = this.replenishmentState.value;
    try {
      const result = await createReplenishmentOrder({
        request: {
          storeId: state.storeId,
          requestedDate: state.orderDate,
          notes: state.orderNotes,
          selections: state.chosenProducts.map((product) => ({
            productId: product.productId,
            quantity: product.quantity
          }))
        }
      });
      this.orderId = result?.orderId || result?.Id || result;
      this.orderNumber =
        result?.orderNumber || result?.OrderNumber || 'Created order';
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Replenishment order created',
          message: `${this.orderNumber} is ready for review.`,
          variant: 'success'
        })
      );
      this.dispatchEvent(
        new CustomEvent('ordercreated', {
          detail: { orderId: this.orderId }
        })
      );
    } catch (error) {
      this.errorMessage = this.reduceError(error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Could not create order',
          message: this.errorMessage,
          variant: 'error'
        })
      );
    } finally {
      this.isCreating = false;
    }
  }

  handleViewOrder() {
    if (!this.orderId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: this.orderId,
        objectApiName: 'Order',
        actionName: 'view'
      }
    });
  }

  async handleAskAgentforce() {
    if (!this.botId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Agentforce bot ID required',
          message: 'Configure the public botId property for this wizard.',
          variant: 'warning'
        })
      );
      return;
    }
    this.isAskingAgent = true;
    try {
      await open(this.botId);
      const utterance = `Review replenishment needs for ${this.storeName}. I just created order ${this.orderNumber}. Show the current assortment-aware inventory risks and recommended quantities.`;
      await execute(utterance, this.botId);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Agentforce is unavailable',
          message: this.reduceError(error),
          variant: 'error'
        })
      );
    } finally {
      this.isAskingAgent = false;
    }
  }

  reduceError(error) {
    return (
      error?.body?.message || error?.message || 'An unexpected error occurred.'
    );
  }
}