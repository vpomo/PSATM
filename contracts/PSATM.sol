pragma solidity ^0.4.23;


library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function max64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a < b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract PSATM {
    using SafeMath for uint256;

    /*=================================
    =            MODIFIERS            =
    =================================*/
    // only people with tokens
    modifier onlyBagholders() {
        require(myTokens() > 0);
        _;
    }

    // only people with profits
    modifier onlyStronghands() {
        require(myDividends(true) > 0);
        _;
    }

    // administrators can:
    // -> change the name of the contract
    // -> change the name of the token
    // -> change the PoS difficulty (How many tokens it costs to hold a masternode, in case it gets crazy high later)
    // they CANNOT:
    // -> take funds
    // -> disable withdrawals
    // -> kill the contract
    // -> change the price of tokens
    modifier onlyAdministrator(){
        address _customerAddress = msg.sender;
        require(administrators[keccak256(_customerAddress)]);
        _;
    }

    /*==============================
    =            EVENTS            =
    ==============================*/
    event OnTokenPurchase(
        address indexed customerAddress,
        uint256 incomingEthereum,
        uint256 tokensMinted,
        address indexed referredBy
    );

    event OnTokenSell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 ethereumEarned
    );

    event OnReinvestment(
        address indexed customerAddress,
        uint256 ethereumReinvested,
        uint256 tokensMinted
    );

    event OnWithdraw(
        address indexed customerAddress,
        uint256 ethereumWithdrawn
    );

    // ERC20
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokens
    );


    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    string public name = "Profit Sharing Automated Token Machine";
    string public symbol = "PSATM";
    uint8 constant public decimals = 18;
    uint8 constant internal dividendFeeBuy_ = 15;
    uint8 constant internal dividendFeeSell_ = 10;
    uint256 constant internal tokenPriceInitial_ = 0.00000001 ether;
    uint256 constant internal tokenPriceIncremental_ = 0.000000001 ether;
    uint256 constant internal tokenPriceIncrementalBuy_ = 0.0000000015 ether;
    uint256 constant internal magnitude = 2**64;

    // proof of stake (defaults at 100 tokens)
    uint256 public stakingRequirement = 100e18;

    // ambassador program
    mapping(address => bool) internal ambassadors_;
    uint256 constant internal ambassadorMaxPurchase_ = 1 ether;
    uint256 constant internal ambassadorQuota_ = 20 ether;

    /*================================
     =            DATASETS            =
     ================================*/
    // amount of shares for each address (scaled number)
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    mapping(address => uint256) internal ambassadorAccumulatedQuota_;
    uint256 internal tokenSupply_ = 0;
    uint256 internal profitPerShare_;

    // administrator list (see above on what they can do)
    mapping(bytes32 => bool) public administrators;

    // when this is set to true, only ambassadors can purchase tokens (this prevents a whale premine, it ensures a fairly distributed upper pyramid)
    bool public onlyAmbassadors = true;

    address public ownerFundResearch;
    uint256 fundResearch = 0;



    /*=======================================
    =            PUBLIC FUNCTIONS            =
    =======================================*/
    /*
    * -- APPLICATION ENTRY POINTS --
    */
    constructor(address _ownerFundResearch) public {
        ownerFundResearch = _ownerFundResearch;
    }


    /**
     * Converts all incoming ethereum to tokens for the caller, and passes down the referral addy (if any)
     */
    function buy(address _referredBy) public
    payable
    returns(uint256)
    {
        purchaseTokens(msg.value, _referredBy);
    }

    /**
     * Fallback function to handle ethereum that was send straight to the contract
     * Unfortunately we cannot use a referral address this way.
     */
    function()
    payable
    public
    {
        purchaseTokens(msg.value, 0x0);
    }

    /**
     * Converts all of caller's dividends to tokens.
     */
    function reinvest()
    onlyStronghands()
    public
    {
        // fetch dividends
        uint256 _dividends = myDividends(false); // retrieve ref. bonus later in the code

        // pay out the dividends virtually
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);

        // retrieve ref. bonus
        _dividends = _dividends.add(referralBalance_[_customerAddress]);
        referralBalance_[_customerAddress] = 0;

        // dispatch a buy order with the virtualized "withdrawn dividends"
        uint256 _tokens = purchaseTokens(_dividends, address(0));

        // fire event
        emit OnReinvestment(_customerAddress, _dividends, _tokens);
    }

    /**
     * Alias of sell() and withdraw().
     */
    function exit()
    public
    {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if(_tokens > 0) sell(_tokens);

        // lambo delivery service
        withdraw();
    }

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw()
    onlyStronghands()
    public
    {
        // setup data
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false); // get ref. bonus later in the code

        // update dividend tracker
        //payoutsTo_[_customerAddress] = payoutsTo_[_customerAddress].add(_dividends.mul(magnitude));
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);

        // add ref. bonus
        _dividends = _dividends.add(referralBalance_[_customerAddress]);
        referralBalance_[_customerAddress] = 0;

        // lambo delivery service
        _customerAddress.transfer(_dividends);

        // fire event
        emit OnWithdraw(_customerAddress, _dividends);
    }

    function withdrawFundRecearch() public {
        address _customerAddress = msg.sender;
        require(_customerAddress != address(0));
        if (_customerAddress == ownerFundResearch) {
            ownerFundResearch.transfer(fundResearch);
        }
    }

    /**
     * Liquifies tokens to ethereum.
     */
    function sell(uint256 _amountOfTokens)
    onlyBagholders()
    public
    {
        // setup data
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = tokensToEthereum_(_tokens);
        uint256 _dividends = _ethereum.div(dividendFeeSell_);
        uint256 _taxedEthereum = _ethereum.sub(_dividends);

        // burn the sold tokens
        tokenSupply_ = tokenSupply_.sub(_tokens);
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].sub(_tokens);

        // update dividends tracker
        //_updatedPayouts = profitPerShare_.mul(_tokens).add(_taxedEthereum.mul(magnitude));
        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedEthereum * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;

        // dividing by zero is a bad idea
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ = profitPerShare_.add(_dividends.mul(magnitude).div(tokenSupply_));
        }

        // fire event
        emit OnTokenSell(_customerAddress, _tokens, _taxedEthereum);
    }


    /**
     * Transfer tokens from the caller to a new holder.
     * Remember, there's a 10% fee here as well.
     */
    function transfer(address _toAddress, uint256 _amountOfTokens)
    onlyBagholders()
    public
    returns(bool)
    {
        // setup
        address _customerAddress = msg.sender;

        // make sure we have the requested tokens
        // also disables transfers until ambassador phase is over
        // ( we dont want whale premines )
        require(!onlyAmbassadors && _amountOfTokens <= tokenBalanceLedger_[_customerAddress]);

        // withdraw all outstanding dividends first
        if(myDividends(true) > 0) withdraw();

        // liquify 10% of the tokens that are transfered
        // these are dispersed to shareholders
        uint256 _tokenFee = _amountOfTokens.div(dividendFeeSell_);
        uint256 _taxedTokens = _amountOfTokens.sub(_tokenFee);
        uint256 _dividends = tokensToEthereum_(_tokenFee);

        // burn the fee tokens
        tokenSupply_ = tokenSupply_.sub(_tokenFee);

        // exchange tokens
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].sub(_amountOfTokens);
        tokenBalanceLedger_[_toAddress] = tokenBalanceLedger_[_toAddress].add(_taxedTokens);

        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);

        // disperse dividends among holders
        profitPerShare_ = profitPerShare_.add(_dividends.mul(magnitude).div(tokenSupply_));

        // fire event
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);

        // ERC20
        return true;

    }

    /*----------  ADMINISTRATOR ONLY FUNCTIONS  ----------*/
    /**
     * In case the amassador quota is not met, the administrator can manually disable the ambassador phase.
     */
    function disableInitialStage()
    onlyAdministrator()
    public
    {
        onlyAmbassadors = false;
    }

    /**
     * In case one of us dies, we need to replace ourselves.
     */
    function setAdministrator(bytes32 _identifier, bool _status)
    onlyAdministrator()
    public
    {
        administrators[_identifier] = _status;
    }

    /**
     * Precautionary measures in case we need to adjust the masternode rate.
     */
    function setStakingRequirement(uint256 _amountOfTokens)
    onlyAdministrator()
    public
    {
        stakingRequirement = _amountOfTokens;
    }

    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current Ethereum stored in the contract
     * Example: totalEthereumBalance()
     */
    function totalEthereumBalance()
    public
    view
    returns(uint)
    {
        return address(this).balance;
    }

    /**
     * Retrieve the total token supply.
     */
    function totalSupply()
    public
    view
    returns(uint256)
    {
        return tokenSupply_;
    }

    /**
     * Retrieve the tokens owned by the caller.
     */
    function myTokens()
    public
    view
    returns(uint256)
    {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }

    /**
     * Retrieve the dividends owned by the caller.
     * If `_includeReferralBonus` is to to 1/true, the referral bonus will be included in the calculations.
     * The reason for this, is that in the frontend, we will want to get the total divs (global + ref)
     * But in the internal calculations, we want them separate.
     */
    function myDividends(bool _includeReferralBonus)
    public
    view
    returns(uint256)
    {
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress).add(referralBalance_[_customerAddress]) : dividendsOf(_customerAddress) ;
    }

    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(address _customerAddress)
    view
    public
    returns(uint256)
    {
        return tokenBalanceLedger_[_customerAddress];
    }

    /**
     * Retrieve the dividend balance of any single address.
     */
    function dividendsOf(address _customerAddress)
    view
    public
    returns(uint256)
    {
        return (uint256) ((int256)(profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }

    /**
     * Return the buy price of 1 individual token.
     */
    function sellPrice()
    public
    view
    returns(uint256)
    {
        // our calculation relies on the token supply, so we need supply. Doh.
        if(tokenSupply_ == 0){
            return tokenPriceInitial_.sub(tokenPriceIncremental_);
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = _ethereum.div(dividendFeeSell_);
            uint256 _taxedEthereum = _ethereum.sub(_dividends);
            return _taxedEthereum;
        }
    }

    /**
     * Return the sell price of 1 individual token.
     */
    function buyPrice()
    public
    view
    returns(uint256)
    {
        // our calculation relies on the token supply, so we need supply. Doh.
        if(tokenSupply_ == 0){
            return tokenPriceInitial_.add(tokenPriceIncrementalBuy_);
        } else {
            uint256 _ethereum = tokensToEthereum_(1e18);
            uint256 _dividends = _ethereum.div(dividendFeeBuy_);
            uint256 _taxedEthereum = _ethereum.add(_dividends);
            return _taxedEthereum;
        }
    }

    /**
     * Function for the frontend to dynamically retrieve the price scaling of buy orders.
     */
    function calculateTokensReceived(uint256 _ethereumToSpend)
    public
    view
    returns(uint256)
    {
        uint256 _dividends = _ethereumToSpend.div(dividendFeeBuy_);
        uint256 _taxedEthereum = _ethereumToSpend.sub(_dividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);

        return _amountOfTokens;
    }

    /**
     * Function for the frontend to dynamically retrieve the price scaling of sell orders.
     */
    function calculateEthereumReceived(uint256 _tokensToSell)
    public
    view
    returns(uint256)
    {
        require(_tokensToSell <= tokenSupply_);
        uint256 _ethereum = tokensToEthereum_(_tokensToSell);
        uint256 _dividends = _ethereum.div(dividendFeeSell_);
        uint256 _taxedEthereum = _ethereum.sub(_dividends);
        return _taxedEthereum;
    }


    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 _incomingEthereum, address _referredBy)
    internal
    returns(uint256)
    {
        // data setup
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = _incomingEthereum.div(dividendFeeBuy_);
        uint256 _referralBonus = _undividedDividends.div(3);
        fundResearch = _referralBonus;
        uint256 _dividends = _undividedDividends.sub(_referralBonus).sub(fundResearch);
        uint256 _taxedEthereum = _incomingEthereum.sub(_undividedDividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        uint256 _fee = _dividends * magnitude;

        // no point in continuing execution if OP is a poorfag russian hacker
        // prevents overflow in the case that the pyramid somehow magically starts being used by everyone in the world
        // (or hackers)
        // and yes we know that the safemath function automatically rules out the "greater then" equasion.
        require(_amountOfTokens > 0 && (_amountOfTokens.add(tokenSupply_)  > tokenSupply_));

        // is the user referred by a masternode?
        if(
        // is this a referred purchase?
            _referredBy != address(0) &&

            // no cheating!
            _referredBy != _customerAddress &&

            // does the referrer have at least X whole tokens?
            // i.e is the referrer a godly chad masternode
            tokenBalanceLedger_[_referredBy] >= stakingRequirement
        ){
            // wealth redistribution
            referralBalance_[_referredBy] = referralBalance_[_referredBy].add(_referralBonus);
        } else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
            _dividends = _dividends.add(_referralBonus);
            _fee = _dividends * magnitude;
        }

        // we can't give people infinite ethereum
        if(tokenSupply_ > 0){

            // add tokens to the pool
            tokenSupply_ = tokenSupply_.add(_amountOfTokens);

            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare_ += (_dividends * magnitude / (tokenSupply_));

            // calculate the amount of tokens the customer receives over his purchase
            _fee = _fee - (_fee-(_amountOfTokens * (_dividends * magnitude / (tokenSupply_))));

        } else {
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }

        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].add(_amountOfTokens);

        // Tells the contract that the buyer doesn't deserve dividends for the tokens before they owned them;
        //really i know you think you do but you don't
        int256 _updatedPayouts = (int256) ((profitPerShare_ * _amountOfTokens) - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;

        // fire event
        emit OnTokenPurchase(_customerAddress, _incomingEthereum, _amountOfTokens, _referredBy);

        return _amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens_(uint256 _ethereum)
    internal
    view
    returns(uint256)
    {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 valueSqrt = (
        (_tokenPriceInitial**2)
        +
        (2*(tokenPriceIncrementalBuy_ * 1e18)*(_ethereum * 1e18))
        +
        (((tokenPriceIncrementalBuy_)**2)*(tokenSupply_**2))
        +
        (2*(tokenPriceIncrementalBuy_)*_tokenPriceInitial*tokenSupply_)
        );
        uint256 _tokensReceived = valueSqrt.sub(_tokenPriceInitial).div(tokenPriceIncrementalBuy_).sub(tokenSupply_);

        return _tokensReceived;
    }

    /**
     * Calculate token sell value.
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tokensToEthereum_(uint256 _tokens)
    internal
    view
    returns(uint256)
    {

        uint256 tokens_ = _tokens.add(1e18);
        uint256 _tokenSupply = tokenSupply_.add(1e18);
        uint256 valueOne = (
        (
        (
        tokenPriceInitial_ +(tokenPriceIncremental_ * (_tokenSupply/1e18))
        )-tokenPriceIncremental_
        )*(tokens_ - 1e18)
        );
        uint256 valueTwo = (tokenPriceIncremental_*((tokens_**2-tokens_)/1e18))/2;
        uint256 _etherReceived = valueOne.sub(valueTwo).div(1e18);
        return _etherReceived;
    }


    //This is where all your gas goes, sorry
    //Not sorry, you probably only paid 1 gwei
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = x.add(1).div(2);//z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = x.div(z).add(z).div(2);// (x / z + z) / 2;
        }
    }
}


