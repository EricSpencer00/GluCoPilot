import { AnyAction, Dispatch } from '@reduxjs/toolkit';

// Store the Redux dispatch function for use outside components
let _dispatch: Dispatch<AnyAction> | null = null;

export function setReduxDispatch(dispatch: Dispatch<AnyAction>) {
  _dispatch = dispatch;
}

export function getReduxDispatch(): Dispatch<AnyAction> | null {
  return _dispatch;
}
