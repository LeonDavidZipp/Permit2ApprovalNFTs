"use client";

import { useState } from "react";
import ApprovalSettingsTab from "./_components/ApprovalSettingsTab";
import Permit2SettingsTab from "./_components/Permit2SettingsTab";
import { Token } from "./_types";
import type { NextPage } from "next";

const Settings: NextPage = () => {
  return (
    <>
      <div className="flex flex-col items-center">
        <h1 className="text-2xl font-bold">Settings</h1>
        <div className="flex flex-col items-center">
          <ApprovalSettingsTab />
          <Permit2SettingsTab />
        </div>
      </div>
    </>
  );
};

export default Settings;
