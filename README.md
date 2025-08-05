# Cross-chain Rebase Token

1. A protocol that allows users to deposit into a vault and in return receive rebase tokens that represent their underlying balance

2. Rebase token -> balanceOf function is dynamic to show changing balance with time
    - Balance increases linearly with time
    - mint tokens to our users every time they perform an action (minting, burning, transfering or... bridging)
3. Interest rate
    - Indivisually set an interest rate or each user based on some global interest rate of the protocol at the time the user deposit into the vault.
    - This gloabal interest rate can only decrease to incetivise/reward early adaptops.
    - Increase token adaptation.