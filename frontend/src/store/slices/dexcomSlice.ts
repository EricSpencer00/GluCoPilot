import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
// import { Dexcom } from 'pydexcom';

interface DexcomState {
  isLoggedIn: boolean;
  error: string | null;
}

const initialState: DexcomState = {
  isLoggedIn: false,
  error: null,
};

// export const loginToDexcom = createAsyncThunk(
//   'dexcom/login',
//   async (
//     { username, password }: { username: string; password: string },
//     { rejectWithValue }
//   ) => {
//     try {
//       const dexcom = new Dexcom(username, password);
//       // Test login by fetching glucose data
//       await dexcom.getCurrentGlucoseReading();
//       return true;
//     } catch (error: any) {
//       return rejectWithValue(error.message || 'Dexcom login failed');
//     }
//   }
// );

// const dexcomSlice = createSlice({
//   name: 'dexcom',
//   initialState,
//   reducers: {},
//   extraReducers: (builder) => {
//     builder.addCase(loginToDexcom.pending, (state) => {
//       state.error = null;
//     });
//     builder.addCase(loginToDexcom.fulfilled, (state) => {
//       state.isLoggedIn = true;
//     });
//     builder.addCase(loginToDexcom.rejected, (state, action) => {
//       state.error = action.payload as string;
//     });
//   },
// });

// export default dexcomSlice.reducer;
