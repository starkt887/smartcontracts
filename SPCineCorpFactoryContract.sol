// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';

contract SPCineCorpFactoryContract{


TCollect[] allTCollects;
address Admin;
mapping(address=>uint) FactoryRoyaltys;

event NewCollection(
    uint256 indexed date,
    address collectionAddr,
    address indexed from,
    string title,
    string symbol,
    uint indexed royalty
);

mapping(address=>uint) RoyaltyPayers;
event FacRoyaltyPay(
  uint256 indexed date,
    address indexed from,
    address collectionAddr,
    uint indexed royalty
);

event SetFacRoyalty(
  uint256 indexed date,
    address indexed from,
    address partneraddr,
    uint indexed royalty
);

constructor(address admin){
  Admin=admin;
}

  function createTCollect(string memory title,string memory symbol,uint factoryroyalty) external{
      TCollect tCollect=new TCollect(title,symbol,msg.sender,address(this));
      allTCollects.push(tCollect);
      FactoryRoyaltys[msg.sender]=factoryroyalty;
       emit NewCollection(block.timestamp,address(tCollect),msg.sender,title,symbol,factoryroyalty);
  }

/*Overridden functions*/
/*put this function in get live contract collection and verify collection purposes */
  function getAllTCollects() external view returns(TCollect[] memory)
  {
    return allTCollects;
  }
  
  function setFactoryRoyalty(uint facroyalty,address payer) external{
    FactoryRoyaltys[payer]=facroyalty;
     emit SetFacRoyalty(block.timestamp,msg.sender,payer,facroyalty);
  }

  function getFactoryRoyalty(address payer)external view returns(uint)
  {
    return FactoryRoyaltys[payer];
  }
  function royaltyPay(address royaltyPayer)external payable {
    RoyaltyPayers[royaltyPayer]+=msg.value;
    emit FacRoyaltyPay(block.timestamp,royaltyPayer,msg.sender,msg.value);
  }
  function getRoyaltyPayer(address payer)external view returns(uint)
  {
    return RoyaltyPayers[payer];
  }
  function getBalance()external view returns(uint){
    return address(this).balance;
  }
  function withDraw(uint amount)external{
    require(Admin==msg.sender,"Not an admin");
    require(address(this).balance>amount,"Insufficient account balance");
    payable(Admin).transfer(amount);
  }
}

contract TCollect is ERC721URIStorage,ERC721Holder{
   using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    enum buytype{buy,rebuy}

    struct Token_structure{

      address tokenCreator;
      address[] preOwnerList;
      uint256 tokenID;
      uint256 price;
      uint256 sale_price;
      uint256 royalty;
      buytype btype;
    
    }


    mapping(uint256=>Token_structure) token_List;

    event MintNFT(
        uint256 date,
        address indexed collectionAddr,
        address indexed from,
        uint256 indexed tokenid,
        uint256 price,
        uint256 sale_price,
        uint256 royalty
    );
    event NFTUriSet(
      uint256 date,
      address indexed collectionAddr,
        address indexed from,
        uint256 indexed tokenid,
        string tkuri
    );
     event UpdatePrice(
      uint256 date,
      address indexed collectionAddr,
        address indexed from,
        uint256 indexed tokenid,
      uint256 price,
      uint256 sale_price
    );
event TransferNFT(
    uint256 indexed date,
    address indexed collectionAddr,
     uint256 indexed tokenid,
      uint256 price,
      uint facprice,
      uint royaltyprice,
    address from,
    address to,
    buytype btype
);
    address Admin;
    address SuperAdmin;

    constructor(string memory title,string memory symbol,address admin,address superadmin) ERC721(title,symbol) {
        Admin=admin;
        SuperAdmin=superadmin;
        //setApprovalForAll(SuperAdmin, true);
         //setApprovalForAll(SuperAdmin, true);
     }
    function adminOf()external view returns(address)
    {
      return Admin;
    }
     function getTokens(uint256 id)external view returns(Token_structure memory)
    {
        return (token_List[id]);
    }

 

    function mint_nemwNFT(uint256 price,uint256 sale_price,uint256 royalty) external
    {
        _tokenIds.increment();
        uint256 newItemId=_tokenIds.current();
        _mint(msg.sender,newItemId);//msg.sender is the factory contract instance adddress
        _setTokenURI(newItemId, "");
        
        //require(msg.sender==Admin,"Admin can only approve the token");
        //approve(address(this), newItemId);//give approval to contract to transfer this token to other
        
        token_List[newItemId].tokenCreator=Admin;
        token_List[newItemId].tokenID=newItemId;
        token_List[newItemId].price=price;
        token_List[newItemId].sale_price=sale_price;
        token_List[newItemId].royalty=royalty;
        token_List[newItemId].btype=buytype.buy;
        safeTransferFrom(msg.sender,address(this),newItemId);
        
        emit MintNFT(block.timestamp,address(this),msg.sender,newItemId,price,sale_price,royalty);

    }
     function update_NFTtokenUri(uint256 tokenid,string memory tkuri)external{
      _setTokenURI(tokenid,tkuri);
      emit NFTUriSet(block.timestamp, address(this), msg.sender,tokenid,tkuri);
    }
    function update_NFTtokenPrice(uint256 tokenid,uint256 price,uint256 sale_price)external{
      token_List[tokenid].price=price;
      token_List[tokenid].sale_price=sale_price;
      emit UpdatePrice(block.timestamp, address(this), msg.sender,tokenid,price,sale_price);
    }

          function buyNFT_safe(uint256 tokenid)external payable
      {
          address from;
          address to=msg.sender;
        if(token_List[tokenid].btype==buytype.buy)
        {
            from= token_List[tokenid].tokenCreator;
        }
        else
        {
            from= token_List[tokenid].preOwnerList[token_List[tokenid].preOwnerList.length-1];
        }

        require(to!=address(0),"To address is not specified");
        require(to!=from,"Seller should not be buyer");
        if(token_List[tokenid].sale_price==0)
            require(msg.value>=token_List[tokenid].price,"Insufficient wallet balance (:Price)");
        else
            require(msg.value>=token_List[tokenid].sale_price,"Insufficient wallet balance (:sale_price)");

        //Factory royalty
        SPCineCorpFactoryContract facon=SPCineCorpFactoryContract(SuperAdmin);
        uint facroyalty=facon.getFactoryRoyalty(Admin);
        uint facPrice=(msg.value*facroyalty)/1000;
        facon.royaltyPay{value:facPrice}(msg.sender);

        if(token_List[tokenid].btype==buytype.buy)
        { 
          //seller pay
            uint sellerPrice=msg.value-facPrice;
            payable(from).transfer(sellerPrice);
          //transfer token
            this.approve(to,tokenid);
            safeTransferFrom(address(this),to,tokenid);
            approve(address(this),tokenid);
          //update token data
            token_List[tokenid].preOwnerList.push(to);//add new owner in preOwnerList   
            token_List[tokenid].btype=buytype.rebuy;
            emit TransferNFT(block.timestamp,address(this),tokenid,msg.value,facPrice,0,from,to,buytype.buy);
        }
        else
        {
             //sellerpay
            uint sellerPrice=msg.value-facPrice;
            //set price for creator and current owner
            address creator=token_List[tokenid].tokenCreator;
            uint toCreator_val= (sellerPrice*token_List[tokenid].royalty)/1000;//no decimal formula 
            uint256 toOwner_val=sellerPrice-toCreator_val;
        
            payable(creator).transfer(toCreator_val);//to creator
            payable(from).transfer(toOwner_val);//to current owner
            
            //this.approve(to,tokenid);
            //transfer to new buyer
            this.safeTransferFrom(from,to,tokenid);
            approve(address(this),tokenid);

            token_List[tokenid].preOwnerList.push(to);//add new owner in preOwnerList*/
            emit TransferNFT(block.timestamp,address(this),tokenid,msg.value,facPrice,toCreator_val,from,to,buytype.rebuy);
        }   

        /*
        if token can be transfrred by approving
        then
        */

      }
  

      function rebuyNFT_safe(address to,uint256 tokenid)external payable returns(uint256)
      {
         
        address from= token_List[tokenid].preOwnerList[token_List[tokenid].preOwnerList.length-1];
        address creator=token_List[tokenid].tokenCreator;

        require(to!=address(0),"To address is not specified");
        require(to!=from,"Seller should not be buyer");
        require(msg.value>=token_List[tokenid].price,"Insufficient wallet balance");
 
        uint256 toCreator_val= msg.value/100*token_List[tokenid].royalty;
        uint256 toOwner_val=msg.value-toCreator_val;
       
        payable(creator).transfer(toCreator_val);//to creator
        payable(from).transfer(toOwner_val);
        
        //this.approve(to,tokenid);

        this.safeTransferFrom(from,to,tokenid);

        token_List[tokenid].preOwnerList.push(to);//add new owner in preOwnerList*/

        return toCreator_val;

      }
}