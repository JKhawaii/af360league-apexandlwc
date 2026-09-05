import { defineState } from '@lwc/state';

const EMPTY_STATE = Object.freeze({
  storeId: null,
  storeName: '',
  storeType: '',
  orderDate: '',
  chosenProducts: [],
  orderNotes: ''
});

const normalizeQuantity = (value) =>
  Math.max(1, Math.floor(Number(value) || 1));

const createReplenishmentState = defineState(
  ({ atom, computed, setAtom }, initialState = {}) => {
    const state = { ...EMPTY_STATE, ...initialState };
    const storeId = atom(state.storeId);
    const storeName = atom(state.storeName);
    const storeType = atom(state.storeType);
    const orderDate = atom(state.orderDate);
    const chosenProducts = atom(
      Array.isArray(state.chosenProducts)
        ? state.chosenProducts.map((product) => ({ ...product }))
        : []
    );
    const orderNotes = atom(state.orderNotes);

    const productCount = computed(
      [chosenProducts],
      // TODO FOR THE CHALLENGE (Task 1):
      // Replace this callback with one that returns products.length.
      () => 0
    );
    const totalUnits = computed([chosenProducts], (products) =>
      products.reduce(
        (total, product) => total + normalizeQuantity(product.quantity),
        0
      )
    );
    const estimatedTotal = computed([chosenProducts], (products) =>
      products.reduce(
        (total, product) =>
          total +
          normalizeQuantity(product.quantity) *
            (Number(product.unitPrice) || 0),
        0
      )
    );
    const canCreateOrder = computed(
      [storeId, orderDate, chosenProducts],
      (currentStoreId, currentOrderDate, products) =>
        Boolean(
          currentStoreId &&
          currentOrderDate &&
          products.length > 0 &&
          products.every(
            (product) =>
              product.productId && normalizeQuantity(product.quantity) > 0
          )
        )
    );

    const setStore = (nextStore = {}) => {
      setAtom(storeId, nextStore.storeId || null);
      setAtom(storeName, nextStore.storeName || '');
      setAtom(storeType, nextStore.storeType || '');
    };
    const setOrderDate = (value) => setAtom(orderDate, value || '');
    const setOrderNotes = (value) => setAtom(orderNotes, value || '');
    const replaceChosenProducts = (products = []) =>
      setAtom(
        chosenProducts,
        products.map((product) => ({
          ...product,
          quantity: normalizeQuantity(product.quantity)
        }))
      );
    const selectProduct = (product) => {
      if (!product?.productId) {
        return;
      }
      // eslint-disable-next-line no-unused-vars -- used when the TODO is completed
      const withoutProduct = chosenProducts.value.filter(
        (item) => item.productId !== product.productId
      );
      // TODO FOR THE CHALLENGE (Task 1):
      // Use setAtom to publish withoutProduct plus the selected product.
      // Normalize quantity using quantity or defaultOrderQuantity.
    };
    const removeProduct = (productId) =>
      setAtom(
        chosenProducts,
        chosenProducts.value.filter(
          (product) => product.productId !== productId
        )
      );
    const updateProductQuantity = (productId, quantity) =>
      setAtom(
        chosenProducts,
        chosenProducts.value.map((product) => (
          product.productId === productId
            ? { ...product, quantity: normalizeQuantity(product.quantity?? product.defaultOrderQuantity) }
            : product
        ))
      );
    const reset = (nextStore = {}) => {
      setStore(nextStore);
      setAtom(orderDate, '');
      setAtom(chosenProducts, []);
      setAtom(orderNotes, '');
    };

    return {
      storeId,
      storeName,
      storeType,
      orderDate,
      chosenProducts,
      orderNotes,
      productCount,
      totalUnits,
      estimatedTotal,
      canCreateOrder,
      setStore,
      setOrderDate,
      setOrderNotes,
      replaceChosenProducts,
      selectProduct,
      removeProduct,
      updateProductQuantity,
      reset
    };
  }
);

export default createReplenishmentState;
