// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract NftcanMarketplace {
    DCollect[] allDCollects;
    address Admin;
    uint FactoryRoyalty = 25; //default

    event NewCollection(
        uint indexed date,
        address collectionAddr,
        address indexed from,
        string title,
        string symbol,
        uint indexed royalty
    );

    mapping(address => uint) RoyaltyPayers;

    event FacRoyalty(
        uint indexed date,
        address indexed from,
        address collectionAddr,
        uint indexed royalty
    );

    constructor(address admin) {
        Admin = admin;
    }

    function createTCollect(string memory title, string memory symbol)
        external
    {
        DCollect dCollect = new DCollect(
            title,
            symbol,
            msg.sender,
            address(this)
        );
        allDCollects.push(dCollect);
        emit NewCollection(
            block.timestamp,
            address(dCollect),
            msg.sender,
            title,
            symbol,
            FactoryRoyalty
        );
    }

    /*Overridden functions*/
    /*put this function in get live contract collection and verify collection purposes */
    function getAllDCollects() external view returns (DCollect[] memory) {
        return allDCollects;
    }

    function royaltyPay(address royaltyPayer) external payable {
        RoyaltyPayers[royaltyPayer] += msg.value;
        emit FacRoyalty(block.timestamp, royaltyPayer, msg.sender, msg.value);
    }

    function getRoyaltyPayer(address payer) external view returns (uint) {
        return RoyaltyPayers[payer];
    }

    function withDraw(uint amount) external {
        require(Admin == msg.sender, "WD:NA");
        require(address(this).balance > amount, "WD:IB");
        payable(Admin).transfer(amount);
    }
}

contract DCollect is ERC721URIStorage, ERC721Holder {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Token_structure {
        address tokenCreator;
        address[] preOwnerList;
        uint tokenID;
        string tkuri;
        buytype btype;
    }
    enum buytype {
        buy,
        rebuy
    }

    mapping(uint => Token_structure) token_List;

    event MintNFT_bulk(
        uint date,
        address indexed collectionAddr,
        address indexed from,
        uint[] tokenids,
        uint convi_fee
    );
    event MintNFT_single(
        uint date,
        address indexed collectionAddr,
        address indexed from,
        uint tokenid,
        uint convi_fee
    );

     event MintNFT_single_erc20(
        uint date,
        address indexed collectionAddr,
        address indexed from,
        uint tokenid,
        uint erc20_tok_amt
    );


 
    event BuyNFT_single(
        uint indexed date,
        address indexed collectionAddr,
        uint tokenid,
        address from,
        address to,
        uint price,
        uint convi_fee,
        uint royalty
    );
    event BuyNFT_single_erc20(
         uint indexed date,
        address indexed collectionAddr,
        uint tokenid,
        address from,
        address to,
        address tokaddr,
        uint erc20_tok_amt
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


    function stringsEquals(string memory s1, string memory s2)
        private
        pure
        returns (bool)
    {
        bytes memory b1 = bytes(s1);
        bytes memory b2 = bytes(s2);
        uint l1 = b1.length;
        if (l1 != b2.length) return false;
        for (uint i = 0; i < l1; i++) {
            if (b1[i] != b2[i]) return false;
        }
        return true;
    }

    function calculatePercentage(uint percent_val,uint of_val)private pure returns(uint)
    {
        return (percent_val*of_val)/1000;
    }
    //Single Operations
    function mint_nemwNFT_single(uint convi_fee,uint price,string memory tkuri) external payable {
        //Minting charge
        if (convi_fee > 0) {
            NftcanMarketplace dcccon = NftcanMarketplace(SuperAdmin);
            dcccon.royaltyPay{value: calculatePercentage(convi_fee,price)}(msg.sender);
        }

        _tokenIds.increment();
        uint newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId); //msg.sender is the factory contract instance adddress
        _setTokenURI(newItemId, tkuri);
        //require(msg.sender==Admin,"Admin can only approve the token");
        //approve(address(this), newItemId);//give approval to contract to transfer this token to other

        token_List[newItemId].tokenCreator = msg.sender;
        token_List[newItemId].preOwnerList.push(msg.sender);
        token_List[newItemId].tokenID = newItemId;
        token_List[newItemId].tkuri = tkuri;
        token_List[newItemId].btype = buytype.buy;
        //safeTransferFrom(msg.sender,address(this),newItemId);
        approve(address(this), newItemId);

        emit MintNFT_single(
            block.timestamp,
            address(this),
            msg.sender,
            newItemId,
            convi_fee
        );
    }

    function mint_nemwNFT_single_erc20(address tokaddr,uint erc20_tok_amt) external
    {

      //Minting charge
      
        IERC20 _tokaddr=IERC20(tokaddr);
        _tokaddr.transferFrom(msg.sender,SuperAdmin,(erc20_tok_amt*10**18));

        _tokenIds.increment();
        uint newItemId=_tokenIds.current();
        _mint(msg.sender,newItemId);
        

        
        token_List[newItemId].tokenCreator=msg.sender;
        token_List[newItemId].preOwnerList.push(msg.sender);
        token_List[newItemId].tokenID=newItemId;
        token_List[newItemId].btype = buytype.buy;

        approve(address(this), newItemId);


        emit MintNFT_single_erc20(block.timestamp,address(this),msg.sender,newItemId,erc20_tok_amt);

    }



    function BuyNFT_safe_single(
        uint tokenid,
        uint convi_fee,
        uint royalty,
        uint price
    ) external payable {
        address from = token_List[tokenid].preOwnerList[
            token_List[tokenid].preOwnerList.length - 1
        ];
        address to = msg.sender;
        require(to != address(0), "TSS:TADDNS"); //to is not specified
        require(from != address(0), "TSS:FADDNS"); //from is not specified
        require(to != from, "TSS:CTS"); //cannot transfer to self
        require(msg.value >= price, "IB"); //insufficient balance

        //chk for balance of user with (price,convi_fee,royalty) at front-end level

        if (convi_fee > 0) {
            //Transferring charge
            NftcanMarketplace dcccon = NftcanMarketplace(SuperAdmin);
            dcccon.royaltyPay{value: calculatePercentage(convi_fee,price)}(msg.sender);
        }
        if (token_List[tokenid].btype == buytype.buy) {
            payable(from).transfer(msg.value - calculatePercentage(convi_fee,price));
            token_List[tokenid].btype = buytype.rebuy;
        } else if (token_List[tokenid].btype == buytype.rebuy) {
          
            payable(token_List[tokenid].tokenCreator).transfer(calculatePercentage(royalty,msg.value));
            payable(from).transfer(msg.value - calculatePercentage(convi_fee,price) - calculatePercentage(royalty,msg.value));
        }

        //transfer token
        this.safeTransferFrom(from, to, tokenid);
        token_List[tokenid].preOwnerList.push(to);
        approve(address(this), tokenid);

        //emit event of transfering the nft to its rightful owner
        emit BuyNFT_single(
            block.timestamp,
            address(this),
            tokenid,
            from,
            to,
            msg.value,
            convi_fee,
            royalty
        );
    }

    function BuyNFT_safe_single_erc20(
       uint tokenid,
        address tokaddr,
        uint erc20_tok_amt
    ) external {
        address from = token_List[tokenid].preOwnerList[
            token_List[tokenid].preOwnerList.length - 1
        ];
        address to = msg.sender;
        require(to != address(0), "TSS:TADDNS"); //to is not specified
        require(from != address(0), "TSS:FADDNS"); //from is not specified
        require(to != from, "TSS:CTS"); //cannot transfer to self

        //Transferring charge
       

          if (token_List[tokenid].btype == buytype.buy) {
            IERC20 _tokaddr = IERC20(tokaddr);
            _tokaddr.transferFrom(msg.sender, SuperAdmin, (erc20_tok_amt * 10**18));
            token_List[tokenid].btype = buytype.rebuy;
        } else if (token_List[tokenid].btype == buytype.rebuy) {
            IERC20 _tokaddr = IERC20(tokaddr);
            _tokaddr.transferFrom(msg.sender, SuperAdmin, (erc20_tok_amt * 10**18));

            /*uint creator_royalty = (msg.value * royalty) / 1000;
            payable(token_List[tokenid].tokenCreator).transfer(creator_royalty);
            payable(from).transfer(msg.value - convi_fee - creator_royalty);*/
        }
        
        //transfer toke
        this.safeTransferFrom(from, to, tokenid);
        token_List[tokenid].preOwnerList.push(to);
        approve(address(this), tokenid);
 

        //emit event of transfering the nft to its rightful owner
        emit BuyNFT_single_erc20(
            block.timestamp,
            address(this),
            tokenid,
            from,
            to,
            tokaddr,
            erc20_tok_amt
        );
    }

    //Bulk Operations
    uint[] evt_tokenids;

    function mint_nemwNFT_bulk(uint bulkcnt,uint convi_fee,uint price,string memory tkuri) external payable {
        //Minting charge
        if (convi_fee > 0) {
            NftcanMarketplace dcccon = NftcanMarketplace(SuperAdmin);
            dcccon.royaltyPay{value: calculatePercentage(convi_fee,price)}(msg.sender);
        }

        //reset event arrays
        delete evt_tokenids;
        for (uint i = 0; i < bulkcnt; i++) {
            _tokenIds.increment();
            uint newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId); //msg.sender is the factory contract instance adddress
            _setTokenURI(newItemId,tkuri);
            //require(msg.sender==Admin,"Admin can only approve the token");
            //approve(address(this), newItemId);//give approval to contract to transfer this token to other

            token_List[newItemId].tokenCreator = msg.sender;
            token_List[newItemId].preOwnerList.push(msg.sender);
            token_List[newItemId].tokenID = newItemId;
            token_List[newItemId].btype = buytype.buy;
            token_List[newItemId].tkuri=tkuri;
            //safeTransferFrom(msg.sender,address(this),newItemId);
            approve(address(this), newItemId);
            evt_tokenids.push(newItemId);
        }
        emit MintNFT_bulk(
            block.timestamp,
            address(this),
            msg.sender,
            evt_tokenids,
            convi_fee
        );
    }
}
