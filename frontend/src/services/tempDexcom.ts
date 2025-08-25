export interface TempDexcomCreds {
  username: string;
  password: string;
  ous?: boolean;
}

let _tempCreds: TempDexcomCreds | null = null;

export const setTempDexcomCreds = (creds: TempDexcomCreds) => {
  _tempCreds = { ...creds };
};

export const getTempDexcomCreds = (): TempDexcomCreds | null => {
  return _tempCreds ? { ..._tempCreds } : null;
};

export const clearTempDexcomCreds = () => {
  _tempCreds = null;
};
