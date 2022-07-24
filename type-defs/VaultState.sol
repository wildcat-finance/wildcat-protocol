struct VaultState {
  // Max collateralization ratio is ~100%, enforced by setter
  uint14 collateralizationRatioBips;
  // Max APR is ~327%
  int16 annualInterestBips;
  // Max supply is ~160b
  uint97 totalSupply;
  // Max scale factor is ~1500x
  uint97 scaleFactor;
  uint32 lastInterestAccruedTimestamp;

  group ScaleUpdateParams {
    annualInterestBips;
    scaleFactor;
    lastInterestAccruedTimestamp;
  }
}