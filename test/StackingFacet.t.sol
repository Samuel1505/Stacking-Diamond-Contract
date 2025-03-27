// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC1155.sol";
import "../contracts/interfaces/IDiamondCut.sol";

contract DiamondCutFacet {
    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(msg.sender == ds.contractOwner, "Only owner");
        for (uint256 i = 0; i < _diamondCut.length; i++) {
            IDiamondCut.FacetCut memory cut = _diamondCut[i];
            require(cut.facetAddress != address(0), "Invalid facet address");
            for (uint256 j = 0; j < cut.functionSelectors.length; j++) {
                bytes4 selector = cut.functionSelectors[j];
                if (cut.action == IDiamondCut.FacetCutAction.Add) {
                    ds.selectorToFacetAndPosition[selector].facetAddress = cut.facetAddress;
                }
            }
        }
        emit LibDiamond.DiamondCut(_diamondCut, _init, _calldata);
        if (_init != address(0)) {
            (bool success, ) = _init.delegatecall(_calldata);
            require(success, "Init call failed");
        }
    }
}

contract MockERC20 is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;

    constructor() {
        balanceOf[msg.sender] = 1000 ether;
        totalSupply = 1000 ether;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract MockERC721 is IERC721 {
    mapping(uint256 => address) public override ownerOf;
    mapping(address => uint256) public override balanceOf;
    mapping(uint256 => address) public override getApproved;
    mapping(address => mapping(address => bool)) public override isApprovedForAll;

    function setOwner(uint256 tokenId, address owner) external {
        ownerOf[tokenId] = owner;
        balanceOf[owner]++;
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(ownerOf[tokenId] == from, "Not owner");
        ownerOf[tokenId] = to;
        balanceOf[from]--;
        balanceOf[to]++;
    }

    function approve(address, uint256) external override {}
    function safeTransferFrom(address, address, uint256) external override {}
    function safeTransferFrom(address, address, uint256, bytes calldata) external override {}
    function setApprovalForAll(address, bool) external override {}

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

contract MockERC1155 is IERC1155 {
    mapping(address => mapping(uint256 => uint256)) public override balanceOf;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata) external override {
        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;
    }

    function setBalance(address user, uint256 id, uint256 amount) external {
        balanceOf[user][id] = amount;
    }

    function balanceOfBatch(address[] calldata, uint256[] calldata) external pure override returns (uint256[] memory) {
        return new uint256[](0);
    }

    function setApprovalForAll(address, bool) external override {}
    function isApprovedForAll(address, address) external pure override returns (bool) { return false; }
    function safeBatchTransferFrom(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external override {}

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

contract StakingFacetTest is Test {
    Diamond diamond;
    StakingFacet stakingFacet;
    DiamondCutFacet diamondCutFacet;
    MockERC20 erc20;
    MockERC721 erc721;
    MockERC1155 erc1155;

    address user = address(0x123);
    address owner = address(0x456);

    function setUp() public {
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));
        stakingFacet = new StakingFacet();

        // Add StakingFacet to Diamond with all necessary selectors
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](13); // Increased to 13 to include duration()
        selectors[0] = stakingFacet.addSupportedToken.selector;
        selectors[1] = stakingFacet.stakeERC20.selector;
        selectors[2] = stakingFacet.stakeERC721.selector;
        selectors[3] = stakingFacet.stakeERC1155.selector;
        selectors[4] = stakingFacet.unstakeERC20.selector;
        selectors[5] = stakingFacet.getReward.selector;
        selectors[6] = stakingFacet.setRewardsDuration.selector;
        selectors[7] = stakingFacet.notifyRewardAmount.selector;
        selectors[8] = stakingFacet.balanceOf.selector;
        selectors[9] = stakingFacet.earned.selector;
        selectors[10] = stakingFacet.initialize.selector;
        selectors[11] = stakingFacet.rewardPerToken.selector;
        selectors[12] = stakingFacet.duration.selector; // Added to fix testRewardDurationLogic
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // Initialize StakingFacet with owner
        vm.prank(owner);
        StakingFacet(address(diamond)).initialize(owner);

        erc20 = new MockERC20();
        erc721 = new MockERC721();
        erc1155 = new MockERC1155();

        // Mint tokens to user and Diamond
        vm.startPrank(address(this));
        erc20.mint(user, 1000 ether);
        erc20.mint(address(diamond), 200 ether); // Enough for all reward tests
        vm.stopPrank();

        vm.startPrank(owner);
        StakingFacet(address(diamond)).addSupportedToken(address(erc20), 20);
        StakingFacet(address(diamond)).addSupportedToken(address(erc721), 721);
        StakingFacet(address(diamond)).addSupportedToken(address(erc1155), 1155);
        StakingFacet(address(diamond)).setRewardsDuration(30 days);
        StakingFacet(address(diamond)).notifyRewardAmount(100 ether); // Set initial rewards
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(diamond), 1000 ether);
        erc721.setOwner(1, user);
        erc1155.setBalance(user, 1, 100);
        vm.stopPrank();
    }

    // Original Tests
    function testStakeERC20() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 100 ether);
        assertEq(erc20.balanceOf(address(diamond)), 300 ether); // 200 from mint + 100 staked
    }

    function testStakeERC721() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC721(address(erc721), 1);
        assertEq(erc721.ownerOf(1), address(diamond));
    }

    function testStakeERC1155() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC1155(address(erc1155), 1, 50);
        assertEq(erc1155.balanceOf(address(diamond), 1), 50);
    }

    function testEarnedAndGetReward() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 100 ether);
        vm.warp(block.timestamp + 15 days);

        uint256 earned = StakingFacet(address(diamond)).earned(user);
        assertGt(earned, 0);

        vm.prank(user);
        StakingFacet(address(diamond)).getReward();
        assertEq(StakingFacet(address(diamond)).balanceOf(user), earned);
    }

    function testUnstakeERC20() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 100 ether);
        vm.prank(user);
        StakingFacet(address(diamond)).unstakeERC20(address(erc20), 50 ether);
        assertEq(erc20.balanceOf(user), 950 ether); // 1000 - 100 + 50
    }

    function testOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("Only owner");
        StakingFacet(address(diamond)).notifyRewardAmount(100 ether);
    }

    // New Tests
    function testStakeZeroAmountReverts() public {
        vm.expectRevert("Amount must be greater than 0");
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 0);
    }

    function testStakeUnsupportedTokenReverts() public {
        MockERC20 unsupportedToken = new MockERC20();
        
        vm.prank(user);
        unsupportedToken.approve(address(diamond), 100 ether); // Approve for transfer
        vm.expectRevert("Unsupported ERC20");
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(unsupportedToken), 100 ether);
    }

    function testUnstakeMoreThanStakedReverts() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 100 ether);

        vm.expectRevert("Insufficient staked amount");
        vm.prank(user);
        StakingFacet(address(diamond)).unstakeERC20(address(erc20), 150 ether);
    }

    function testRewardPerToken() public {
        vm.prank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 100 ether);
        
        vm.warp(block.timestamp + 15 days);
        
        uint256 rewardPerToken = StakingFacet(address(diamond)).rewardPerToken();
        assertGt(rewardPerToken, 0);
    }

    function testMultipleTokenStaking() public {
        vm.startPrank(user);
        StakingFacet(address(diamond)).stakeERC20(address(erc20), 50 ether);
        StakingFacet(address(diamond)).stakeERC721(address(erc721), 1);
        StakingFacet(address(diamond)).stakeERC1155(address(erc1155), 1, 25);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);
        uint256 earned = StakingFacet(address(diamond)).earned(user);
        assertGt(earned, 0);
    }

    function testRewardDurationLogic() public {
        vm.startPrank(owner);
        uint256 firstFinishAt = block.timestamp + 30 days; // From setUp
        
        // Before first period ends, try to set new duration
        vm.expectRevert("Reward duration not finished");
        StakingFacet(address(diamond)).setRewardsDuration(15 days);
        
        // Warp to after first period
        vm.warp(firstFinishAt + 1);
        
        // Now can set new duration
        StakingFacet(address(diamond)).setRewardsDuration(15 days);
        assertEq(StakingFacet(address(diamond)).duration(), 15 days); // This now works
        vm.stopPrank();
    }
}