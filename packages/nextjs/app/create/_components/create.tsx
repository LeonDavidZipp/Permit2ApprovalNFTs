"use client";

import { useState } from "react";
import { Token } from "../../_types";

const Create: React.FC = () => {
  const [start, setStart] = useState<number>(0);
  const [expiration, setExpiration] = useState<number>(0);
  const [to, setTo] = useState<string>("");
  const [tokens, setTokens] = useState<Token[]>([]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (start && expiration && to) {
      // Perform the desired action here
      console.log("Form submitted with values:", { start, expiration, to, tokens });
    } else {
      alert("Please fill out all fields.");
    }
  };

  return (
    <div className="flex flex-col items-center justify-center h-screen">
      <h1 className="text-6xl mb-8">Create</h1>
      <form onSubmit={handleSubmit} className="flex flex-col space-y-4">
        <input
          type="number"
          placeholder="Start"
          value={start}
          onChange={e => setStart(Number(e.target.value))}
          className="p-2 border border-gray-300 rounded"
        />
        <input
          type="number"
          placeholder="Expiration"
          value={expiration}
          onChange={e => setExpiration(Number(e.target.value))}
          className="p-2 border border-gray-300 rounded"
        />
        <input
          type="text"
          placeholder="To"
          value={to}
          onChange={e => setTo(e.target.value)}
          className="p-2 border border-gray-300 rounded"
        />
        <button type="submit" className="p-2 bg-blue-500 text-white rounded">
          Submit
        </button>
      </form>
    </div>
  );
};

export default Create;
