import React, { useEffect, useState } from "react";
import { Token } from "../../_types";

const ListItem: React.FC<Token> = ({ address, name, symbol, amount }) => {
  return (
    <div className="flex flex-col items-start">
      <span className="text-lg font-bold">{name}</span>
      {/* <Image></Image> */}
      <span className="text-sm">{address}</span>
      <span className="text-sm">{amount}</span>
    </div>
  );
};

const ApprovalSettingsTab = () => {
  //   const tokens = useEffect<Token[]>();
  // call eth method to fetch tokens
  const [tokens, setTokens] = useState<Token[]>([]);
  return (
    <>
      <div className="flex flex-col items-center">
        <span className="text-2xl font-bold">Approval Settings</span>
        <ul>
          {tokens.map(token => (
            <li key={token.name}>
              <ListItem address={token.address} name={token.name} symbol={token.symbol} amount={token.amount} />
            </li>
          ))}
        </ul>
      </div>
    </>
  );
};

export default ApprovalSettingsTab;
