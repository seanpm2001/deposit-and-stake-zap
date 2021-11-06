# @version ^0.3.0
# A "zap" to add liquidity and deposit into gauge in one transaction
# (c) Curve.Fi, 2021

MAX_COINS: constant(int128) = 10
ETH_ADDRESS: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE

# External Contracts
interface ERC20:
    def transfer(_receiver: address, _amount: uint256): nonpayable
    def transferFrom(_sender: address, _receiver: address, _amount: uint256): nonpayable
    def approve(_spender: address, _amount: uint256): nonpayable
    def decimals() -> uint256: view
    def balanceOf(_owner: address) -> uint256: view
    def allowance(_owner : address, _spender : address) -> uint256: view

interface Pool:
    def coins(i: int128) -> address: view
    def underlying_coins(i: int128) -> address: view
    def base_coins(i: int128) -> address: view

interface PoolV1:
    def coins(i: uint256) -> address: view
    def underlying_coins(i: uint256) -> address: view
    def base_coins(i: uint256) -> address: view

interface Pool2:
    def add_liquidity(amounts: uint256[2], min_mint_amount: uint256): payable

interface Pool3:
    def add_liquidity(amounts: uint256[3], min_mint_amount: uint256): payable

interface Pool4:
    def add_liquidity(amounts: uint256[4], min_mint_amount: uint256): payable

interface Pool5:
    def add_liquidity(amounts: uint256[5], min_mint_amount: uint256): payable

interface PoolUseUnderlying2:
    def add_liquidity(amounts: uint256[2], min_mint_amount: uint256, use_underlying: bool): payable

interface PoolUseUnderlying3:
    def add_liquidity(amounts: uint256[3], min_mint_amount: uint256, use_underlying: bool): payable

interface PoolUseUnderlying4:
    def add_liquidity(amounts: uint256[4], min_mint_amount: uint256, use_underlying: bool): payable

interface PoolUseUnderlying5:
    def add_liquidity(amounts: uint256[5], min_mint_amount: uint256, use_underlying: bool): payable

interface Gauge:
    def deposit(lp_token_amount: uint256, addr: address): payable


allowance: HashMap[address, bool]




@payable
@external
@nonreentrant('lock')
def deposit_and_stake(swap: address, lp_token: address, gauge: address, n_coins: int128, amounts: uint256[10], min_mint_amount: uint256, is_v1: bool):
    assert n_coins >= 2, 'n_coins must be >=2'
    assert n_coins <= MAX_COINS, 'n_coins must be <=MAX_COINS'

    if not self.allowance[swap]:
        self.allowance[swap] = True

        for i in range(MAX_COINS):
            if i >= n_coins:
                break

            in_coin: address = ZERO_ADDRESS
            if is_v1:
                in_coin = Pool(swap).coins(i)
            else:
                in_coin = PoolV1(swap).coins(convert(i, uint256))

            if in_coin == ETH_ADDRESS:
                continue

            ERC20(in_coin).approve(swap, MAX_UINT256)

        if ERC20(lp_token).allowance(self, gauge) == 0:
            ERC20(lp_token).approve(gauge, MAX_UINT256)

    # Transfer coins from owner
    has_eth: bool = False
    for i in range(MAX_COINS):
        if i >= n_coins:
            break

        in_amount: uint256 = amounts[i]
        in_coin: address = ZERO_ADDRESS
        if is_v1:
            in_coin = Pool(swap).coins(i)
        else:
            in_coin = PoolV1(swap).coins(convert(i, uint256))

        if in_coin == ETH_ADDRESS:
            assert msg.value == amounts[i]
            has_eth = True
            continue

        if in_amount > 0:
            # "safeTransferFrom" which works for ERC20s which return bool or not
            _response: Bytes[32] = raw_call(
                in_coin,
                concat(
                    method_id("transferFrom(address,address,uint256)"),
                    convert(msg.sender, bytes32),
                    convert(self, bytes32),
                    convert(in_amount, bytes32),
                ),
                max_outsize=32,
            )  # dev: failed transfer
            if len(_response) > 0:
                assert convert(_response, bool)  # dev: failed transfer

    if not has_eth:
        assert msg.value == 0

    if n_coins == 2:
        Pool2(swap).add_liquidity([amounts[0], amounts[1]], min_mint_amount, value=msg.value)
    elif n_coins == 3:
        Pool3(swap).add_liquidity([amounts[0], amounts[1], amounts[2]], min_mint_amount, value=msg.value)
    elif n_coins == 4:
        Pool4(swap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3]], min_mint_amount, value=msg.value)
    elif n_coins == 5:
        Pool5(swap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3], amounts[4]], min_mint_amount, value=msg.value)

    lp_token_amount: uint256 = ERC20(lp_token).balanceOf(self)
    assert lp_token_amount > 0 # dev: swap-token mismatch

    Gauge(gauge).deposit(lp_token_amount, msg.sender)


@payable
@external
@nonreentrant('lock')
def deposit_and_stake_underlying(swap: address, lp_token: address, gauge: address, n_coins: int128, amounts: uint256[10], min_mint_amount: uint256, is_v1: bool):
    assert n_coins >= 2, 'n_coins must be >=2'
    assert n_coins <= MAX_COINS, 'n_coins must be <=MAX_COINS'

    if not self.allowance[swap]:
        self.allowance[swap] = True
        for i in range(MAX_COINS):
            if i >= n_coins:
                break

            in_coin: address = ZERO_ADDRESS
            if is_v1:
                in_coin = Pool(swap).underlying_coins(i)
            else:
                in_coin = PoolV1(swap).underlying_coins(convert(i, uint256))

            if in_coin == ETH_ADDRESS:
                continue

            ERC20(in_coin).approve(swap, MAX_UINT256)

        if ERC20(lp_token).allowance(self, gauge) == 0:
            ERC20(lp_token).approve(gauge, MAX_UINT256)

    # Transfer coins from owner
    has_eth: bool = False
    for i in range(MAX_COINS):
        if i >= n_coins:
            break

        in_amount: uint256 = amounts[i]
        in_coin: address = ZERO_ADDRESS
        if is_v1:
            in_coin = Pool(swap).underlying_coins(i)
        else:
            in_coin = PoolV1(swap).underlying_coins(convert(i, uint256))

        if in_coin == ETH_ADDRESS:
            assert msg.value == amounts[i]
            has_eth = True
            continue

        if in_amount > 0:
            # "safeTransferFrom" which works for ERC20s which return bool or not
            _response: Bytes[32] = raw_call(
                in_coin,
                concat(
                    method_id("transferFrom(address,address,uint256)"),
                    convert(msg.sender, bytes32),
                    convert(self, bytes32),
                    convert(in_amount, bytes32),
                ),
                max_outsize=32,
            )  # dev: failed transfer
            if len(_response) > 0:
                assert convert(_response, bool)  # dev: failed transfer

    if not has_eth:
        assert msg.value == 0

    if n_coins == 2:
        PoolUseUnderlying2(swap).add_liquidity([amounts[0], amounts[1]], min_mint_amount, True, value=msg.value)
    elif n_coins == 3:
        PoolUseUnderlying3(swap).add_liquidity([amounts[0], amounts[1], amounts[2]], min_mint_amount, True, value=msg.value)
    elif n_coins == 4:
        PoolUseUnderlying4(swap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3]], min_mint_amount, True, value=msg.value)
    elif n_coins == 5:
        PoolUseUnderlying5(swap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3], amounts[4]], min_mint_amount, True, value=msg.value)

    lp_token_amount: uint256 = ERC20(lp_token).balanceOf(self)
    assert lp_token_amount > 0  # dev: swap-token mismatch

    Gauge(gauge).deposit(lp_token_amount, msg.sender)


@payable
@external
@nonreentrant('lock')
def deposit_and_stake_underlying_zap(zap: address, lp_token: address, gauge: address, n_coins: int128, amounts: uint256[10], min_mint_amount: uint256, is_v1: bool):
    assert n_coins >= 2, 'n_coins must be >=2'
    assert n_coins <= MAX_COINS, 'n_coins must be <=MAX_COINS'

    if not self.allowance[zap]:
        self.allowance[zap] = True

        for i in range(MAX_COINS):
            if i >= n_coins:
                break

            in_coin: address = ZERO_ADDRESS
            if is_v1:
                in_coin = Pool(zap).underlying_coins(i)
            else:
                in_coin = PoolV1(zap).underlying_coins(convert(i, uint256))

            if in_coin == ETH_ADDRESS:
                continue

            ERC20(in_coin).approve(zap, MAX_UINT256)

        if ERC20(lp_token).allowance(self, gauge) == 0:
            ERC20(lp_token).approve(gauge, MAX_UINT256)

    # Transfer coins from owner
    has_eth: bool = False
    for i in range(MAX_COINS):
        if i >= n_coins:
            break

        in_amount: uint256 = amounts[i]
        in_coin: address = ZERO_ADDRESS
        if is_v1:
            in_coin = Pool(zap).underlying_coins(i)
        else:
            in_coin = PoolV1(zap).underlying_coins(convert(i, uint256))

        if in_coin == ETH_ADDRESS:
            assert msg.value == amounts[i]
            has_eth = True
            continue

        if in_amount > 0:
            # "safeTransferFrom" which works for ERC20s which return bool or not
            _response: Bytes[32] = raw_call(
                in_coin,
                concat(
                    method_id("transferFrom(address,address,uint256)"),
                    convert(msg.sender, bytes32),
                    convert(self, bytes32),
                    convert(in_amount, bytes32),
                ),
                max_outsize=32,
            )  # dev: failed transfer
            if len(_response) > 0:
                assert convert(_response, bool)  # dev: failed transfer

    if not has_eth:
        assert msg.value == 0

    if n_coins == 2:
        Pool2(zap).add_liquidity([amounts[0], amounts[1]], min_mint_amount, value=msg.value)
    elif n_coins == 3:
        Pool3(zap).add_liquidity([amounts[0], amounts[1], amounts[2]], min_mint_amount, value=msg.value)
    elif n_coins == 4:
        Pool4(zap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3]], min_mint_amount, value=msg.value)
    elif n_coins == 5:
        Pool5(zap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3], amounts[4]], min_mint_amount, value=msg.value)

    lp_token_amount: uint256 = ERC20(lp_token).balanceOf(self)
    assert lp_token_amount > 0 # dev: swap-token mismatch

    Gauge(gauge).deposit(lp_token_amount, msg.sender)


@payable
@external
@nonreentrant('lock')
def deposit_and_stake_underlying_meta(zap: address, lp_token: address, gauge: address, n_coins: int128, amounts: uint256[10], min_mint_amount: uint256, is_v1: bool):
    assert n_coins >= 2, 'n_coins must be >=2'
    assert n_coins <= MAX_COINS, 'n_coins must be <=MAX_COINS'

    if not self.allowance[zap]:
        self.allowance[zap] = True

        for i in range(MAX_COINS):
            if i >= n_coins:
                break

            in_coin: address = ZERO_ADDRESS
            if is_v1:
                if i == 0:
                    in_coin = Pool(zap).coins(i)
                else:
                    in_coin = Pool(zap).base_coins(i - 1)
            else:
                if i == 0:
                    in_coin = PoolV1(zap).coins(convert(i, uint256))
                else:
                    in_coin = PoolV1(zap).base_coins(convert(i - 1, uint256))

            if in_coin == ETH_ADDRESS:
                continue

            ERC20(in_coin).approve(zap, MAX_UINT256)

        if ERC20(lp_token).allowance(self, gauge) == 0:
            ERC20(lp_token).approve(gauge, MAX_UINT256)

    # Transfer coins from owner
    has_eth: bool = False
    for i in range(MAX_COINS):
        if i >= n_coins:
            break

        in_amount: uint256 = amounts[i]
        in_coin: address = ZERO_ADDRESS
        if is_v1:
            if i == 0:
                in_coin = Pool(zap).coins(i)
            else:
                in_coin = Pool(zap).base_coins(i - 1)
        else:
            if i == 0:
                in_coin = PoolV1(zap).coins(convert(i, uint256))
            else:
                in_coin = PoolV1(zap).base_coins(convert(i - 1, uint256))

        if in_coin == ETH_ADDRESS:
            assert msg.value == amounts[i]
            has_eth = True
            continue

        if in_amount > 0:
            # "safeTransferFrom" which works for ERC20s which return bool or not
            _response: Bytes[32] = raw_call(
                in_coin,
                concat(
                    method_id("transferFrom(address,address,uint256)"),
                    convert(msg.sender, bytes32),
                    convert(self, bytes32),
                    convert(in_amount, bytes32),
                ),
                max_outsize=32,
            )  # dev: failed transfer
            if len(_response) > 0:
                assert convert(_response, bool)  # dev: failed transfer

    if not has_eth:
        assert msg.value == 0

    if n_coins == 2:
        Pool2(zap).add_liquidity([amounts[0], amounts[1]], min_mint_amount, value=msg.value)
    elif n_coins == 3:
        Pool3(zap).add_liquidity([amounts[0], amounts[1], amounts[2]], min_mint_amount, value=msg.value)
    elif n_coins == 4:
        Pool4(zap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3]], min_mint_amount, value=msg.value)
    elif n_coins == 5:
        Pool5(zap).add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3], amounts[4]], min_mint_amount, value=msg.value)

    lp_token_amount: uint256 = ERC20(lp_token).balanceOf(self)
    assert lp_token_amount > 0 # dev: swap-token mismatch

    Gauge(gauge).deposit(lp_token_amount, msg.sender)


@payable
@external
def __default__():
    pass
