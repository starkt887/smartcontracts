// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AfterLifedigi {
    DigiReps[] allDigiRepss;
    address Admin;
    uint256 FactoryRoyalty = 25; //default

    event NewCollection(
        uint256 indexed date,
        address collectionAddr,
        address indexed from,
        string title,
        string symbol,
        uint256 indexed royalty
    );

    mapping(address => uint256) RoyaltyPayers;

    event FacRoyalty(
        uint256 indexed date,
        address indexed from,
        address collectionAddr,
        uint256 indexed royalty
    );

    constructor(address admin) {
        Admin = admin;
    }

    function createTCollect(string memory title, string memory symbol)
        external
    {
        DigiReps digiReps = new DigiReps(
            title,
            symbol,
            msg.sender,
            address(this)
        );
        allDigiRepss.push(digiReps);
        emit NewCollection(
            block.timestamp,
            address(digiReps),
            msg.sender,
            title,
            symbol,
            FactoryRoyalty
        );
    }

    /*Overridden functions*/
    /*put this function in get live contract collection and verify collection purposes */
    function getAllDigiRepss() external view returns (DigiReps[] memory) {
        return allDigiRepss;
    }

    function royaltyPay(address royaltyPayer) external payable {
        RoyaltyPayers[royaltyPayer] += msg.value;
        emit FacRoyalty(block.timestamp, royaltyPayer, msg.sender, msg.value);
    }

    function getRoyaltyPayer(address payer) external view returns (uint256) {
        return RoyaltyPayers[payer];
    }

    function withDraw(uint256 amount) external {
        require(Admin == msg.sender, "WD:NA");
        require(address(this).balance > amount, "WD:IB");
        payable(Admin).transfer(amount);
    }
}

contract DigiReps is ERC721URIStorage, ERC721Holder {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Token_structure {
        address tokenCreator;
        address[] preOwnerList;
        uint256 tokenID;
        string data;
    }

    mapping(uint256 => Token_structure) token_List;

    event MintNFT_bulk(
        uint256 date,
        address indexed collectionAddr,
        address indexed from,
        uint256[] tokenid
    );
    event TransferNFT_bulk(
        uint256 indexed date,
        address indexed collectionAddr,
        uint256[] tokenid,
        address from,
        address to
    );
    event MintNFT_single(
        uint256 date,
        address indexed collectionAddr,
        address indexed from,
        uint256 tokenid
    );

    event TransferNFT_single(
        uint256 indexed date,
        address indexed collectionAddr,
        uint256 tokenid,
        address from,
        address to
    );

    event ApproveAdminToNFT_single(
        uint256 indexed date,
        address indexed collectionAddr,
        uint256 tokenid,
        address from,
        address to
    );
    event ApproveAdminToNFT_bulk(
        uint256 indexed date,
        address indexed collectionAddr,
        uint256[] tokenid,
        address from,
        address to
    );
    event NFTUriSet_bulk(
        uint256 date,
        address indexed collectionAddr,
        address indexed from,
        uint256[] tokenid,
        string[] tkuri
    );
    event NFTUriSet_single(
        uint256 date,
        address indexed collectionAddr,
        address indexed from,
        uint256 tokenid,
        string tkuri
    );
    address Admin;
    address SuperAdmin;

    constructor(
        string memory title,
        string memory symbol,
        address admin,
        address superadmin
    ) ERC721(title, symbol) {
        Admin = admin;
        SuperAdmin = superadmin;
    }

    function adminOf() external view returns (address) {
        return Admin;
    }

    //Single Operations
    function mint_nemwNFT_single(string memory data) external {
        //Minting charge

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId); //msg.sender is the factory contract instance adddress
        _setTokenURI(newItemId, data);
        //require(msg.sender==Admin,"Admin can only approve the token");
        //approve(address(this), newItemId);//give approval to contract to transfer this token to other

        token_List[newItemId].tokenCreator = msg.sender;
        token_List[newItemId].preOwnerList.push(msg.sender);
        token_List[newItemId].tokenID = newItemId;
        token_List[newItemId].data = data;

        //safeTransferFrom(msg.sender,address(this),newItemId);
        approve(address(this), newItemId);

        emit MintNFT_single(
            block.timestamp,
            address(this),
            msg.sender,
            newItemId
        );
    }

    function update_NFTtokenUri_single(uint256 tokenid, string memory data)
        external
    {
        _setTokenURI(tokenid, data);
        token_List[tokenid].data = data;
        emit NFTUriSet_single(
            block.timestamp,
            address(this),
            msg.sender,
            tokenid,
            data
        );
    }

    function update_NFTtokenUri_bulk(
        uint256[] memory tokenid,
        string[] memory data
    ) external {
        for (uint256 i = 0; i < tokenid.length; i++) {
            _setTokenURI(tokenid[i], data[i]);
            token_List[tokenid[i]].data = data[i];
        }
        emit NFTUriSet_bulk(
            block.timestamp,
            address(this),
            msg.sender,
            tokenid,
            data
        );
    }

    function TransferNFT_safe_single(uint256 tokenid, address to) external {
        address from = token_List[tokenid].preOwnerList[
            token_List[tokenid].preOwnerList.length - 1
        ];

        require(to != address(0), "TSS:TADDNS"); //to is not specified
        require(from != address(0), "TSS:FADDNS"); //from is not specified
        require(to != from, "TSS:CTS"); //cannot transfer to self

        //transfer token
        this.safeTransferFrom(from, to, tokenid);
        token_List[tokenid].preOwnerList.push(to);

        //emit event of transfering the nft to its rightful owner
        emit TransferNFT_single(
            block.timestamp,
            address(this),
            tokenid,
            from,
            to
        );
    }

    //Bulk Operations
    uint256[] evt_tokenids;

    function mint_nemwNFT_bulk(uint256 bulkcnt, string[] memory datas)
        external
    {
        //reset event arrays
        delete evt_tokenids;
        for (uint256 i = 0; i < bulkcnt; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId); //msg.sender is the factory contract instance adddress
            _setTokenURI(newItemId, datas[i]);
            //require(msg.sender==Admin,"Admin can only approve the token");
            //approve(address(this), newItemId);//give approval to contract to transfer this token to other

            token_List[newItemId].tokenCreator = msg.sender;
            token_List[newItemId].preOwnerList.push(msg.sender);
            token_List[newItemId].tokenID = newItemId;
            token_List[newItemId].data = datas[i];
            //safeTransferFrom(msg.sender,address(this),newItemId);
            approve(address(this), newItemId);
            evt_tokenids.push(newItemId);
        }
        emit MintNFT_bulk(
            block.timestamp,
            address(this),
            msg.sender,
            evt_tokenids
        );
    }

    function transferNFT_safe_bulk(
        uint256[] memory tokenid,
        address merchant_or_owneraddr,
        address nftowneraddr
    ) external {
        address to = nftowneraddr;
        address from = merchant_or_owneraddr;
        require(to != address(0), "TSB:TADDNS");
        require(from != address(0), "TSB:FADDNS");
        require(to != msg.sender, "TSB:CTS");

        for (uint256 i = 0; i < tokenid.length; i++) {
            //transfer token
            this.safeTransferFrom(from, to, tokenid[i]);
            token_List[tokenid[i]].preOwnerList.push(to);
            //emit event of transfering the nft to its rightful owner
        }
        emit TransferNFT_bulk(
            block.timestamp,
            address(this),
            tokenid,
            msg.sender,
            to
        );
    }

    function giveApproval_to(uint256 tokenid, address to) external {
        require(tokenid != 0, "GATCS:IT");
        //approve token
        approve(to, tokenid);
        //approve(Admin,tokenid);
        //emit Event of giving approval to Admin and merchant over the Diamond NFT
        emit ApproveAdminToNFT_single(
            block.timestamp,
            address(this),
            tokenid,
            msg.sender,
            to
        );
    }

    function giveApproval_to_bulk(uint256[] memory tokenid, address to)
        external
    {
        //bulk approval charge

        for (uint256 i = 0; i < tokenid.length; i++) {
            require(tokenid[i] != 0, "Invalide token");
            //approve token
            approve(to, tokenid[i]);
            // approve(Admin,tokenid[i]);
        }
        //emit Event of giving approval to Admin over the Diamond NFT
        emit ApproveAdminToNFT_bulk(
            block.timestamp,
            address(this),
            tokenid,
            msg.sender,
            to
        );
    }

    function getTokenData(uint256 tokenid)
        external
        view
        returns (string memory)
    {
        return token_List[tokenid].data;
    }
}

