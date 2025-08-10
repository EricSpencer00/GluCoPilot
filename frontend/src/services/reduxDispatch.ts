let _dispatch: any = null;

export function setReduxDispatch(dispatch: any) {
  _dispatch = dispatch;
}

export function getReduxDispatch() {
  return _dispatch;
}
