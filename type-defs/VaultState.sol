struct VaultState {
  // Max APR is ~327%
  int16 annualInterestBips;
  // Max supply is ~80
  uint96 scaledTotalSupply;
  // Max scale factor is ~52m
  uint112 scaleFactor;
  uint32 lastInterestAccruedTimestamp unchecked;

  group NewScaleInputs {
    get;

    annualInterestBips;
    scaleFactor;
    lastInterestAccruedTimestamp;
  }

  group NewScaleOutputs {
    set;

    scaleFactor;
    lastInterestAccruedTimestamp;
  }
}