# fhe project

> will deploy the zama infra contracts like ACL, Gateway, TFHEExecutor, etc. they will be called by our
> erc20 contract through the FHE library. (not directly)
> this is part of the one time setup for zama infra contracts, will deploy and save these addresses, which will be used by the coprocessor. ERC20 contract will not call them directly instead wil use the FHE library to call them.
