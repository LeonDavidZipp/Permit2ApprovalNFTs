import { useState } from "react";
import { Token } from "../../_types";

const Permit2SettingsTab = () => {
  const [tokens, setTokens] = useState<Token[]>([]);
  return (
    <>
      <div className="flex flex-col items-center"></div>
    </>
  );
};

export default Permit2SettingsTab;
