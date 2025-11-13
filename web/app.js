// Minimal frontend for Cohort3NFT (uses ethers v6)
;(async () => {
  const CONTRACT_ADDRESS = "0xbdEd0D2bf404bdcBa897a74E6657f1f12e5C6fb6"; // << Set deployed contract address here

  // Minimal ABI subset used by the UI
  const ABI = [
    "function mint(uint256 quantity) payable",
    "function mintPrice() view returns (uint256)",
    "function maxPerWallet() view returns (uint256)",
    "function totalSupply() view returns (uint256)",
    "function revealed() view returns (bool)",
    "function getTokensOfOwner(address) view returns (uint256[] memory)",
    "function tokenURI(uint256) view returns (string memory)",
  ];

  let provider, signer, contract;

  const connectBtn = document.getElementById('connect');
  const accountSpan = document.getElementById('account');
  const contractAddressSpan = document.getElementById('contractAddress');
  const mintPriceSpan = document.getElementById('mintPrice');
  const maxPerWalletSpan = document.getElementById('maxPerWallet');
  const totalMintedSpan = document.getElementById('totalMinted');
  const revealedSpan = document.getElementById('revealed');
  const mintBtn = document.getElementById('mintBtn');
  const quantityInput = document.getElementById('quantity');
  const mintResult = document.getElementById('mintResult');
  const refreshTokens = document.getElementById('refreshTokens');
  const tokensDiv = document.getElementById('tokens');
  const tokenIdInput = document.getElementById('tokenId');
  const getTokenURI = document.getElementById('getTokenURI');
  const tokenURIOutput = document.getElementById('tokenURIOutput');
  const imagePreview = document.getElementById('imagePreview');
  const metadataInfo = document.getElementById('metadataInfo');

  function setContractAddress(addr) {
    contractAddressSpan.textContent = addr || '(set in app.js)';
  }

  setContractAddress(CONTRACT_ADDRESS);

  async function connect() {
    console.log('Connect clicked');
    if (!window.ethereum) {
      alert('Please install MetaMask or another EIP-1193 wallet');
      return;
    }
    try {
      provider = new ethers.BrowserProvider(window.ethereum);
      console.log('Requesting accounts...');
      await provider.send('eth_requestAccounts', []);
    } catch (e) {
      console.error('Account request failed', e);
      alert('Connection failed: ' + (e?.message || e));
      return;
    }

    try {
      signer = await provider.getSigner();
      const addr = await signer.getAddress();
      console.log('Connected address:', addr);
      accountSpan.textContent = addr;

      const target = CONTRACT_ADDRESS || prompt('Enter deployed contract address:');
      if (!target) return;

      contract = new ethers.Contract(target, ABI, signer);
      setContractAddress(target);
      console.log('Contract initialized at', target);
      await refreshConfig();
    } catch (e) {
      console.error('Error initializing contract or signer', e);
      alert('Failed to initialize contract: ' + (e?.message || e));
    }
  }

  async function refreshConfig() {
    if (!contract) return;
    try {
      const [mintPrice, maxPerWallet, totalMinted, revealed] = await Promise.all([
        contract.mintPrice(),
        contract.maxPerWallet(),
        contract.totalSupply(),
        contract.revealed(),
      ]);
      mintPriceSpan.textContent = ethers.formatEther(mintPrice) + ' ETH';
      maxPerWalletSpan.textContent = maxPerWallet.toString();
      totalMintedSpan.textContent = totalMinted.toString();
      revealedSpan.textContent = revealed ? 'true' : 'false';
    } catch (err) {
      console.error(err);
      alert('Failed to read contract config - check contract address and network');
    }
  }

  async function mint() {
    const q = Number(quantityInput.value || '1');
    if (!contract || !signer) return alert('Connect first');

    try {
      console.log('Reading mintPrice...');
      const price = await contract.mintPrice(); // BigInt
      console.log('mintPrice (wei):', price.toString());

      const total = price * BigInt(q); // BigInt math
      console.log('Total price (wei):', total.toString());

      // Send mint transaction (MetaMask popup)
      const tx = await contract.mint(q, { value: total });
      mintResult.textContent = 'Transaction sent: ' + tx.hash;
      console.log('tx sent:', tx);
      await tx.wait();
      mintResult.textContent = 'Mint confirmed: ' + tx.hash;
      console.log('tx confirmed');
      await refreshConfig();
    } catch (err) {
      console.error('Mint error:', err);
      // helpful message
      mintResult.textContent = 'Mint failed: ' + (err?.reason || err?.message || err);
      alert('Mint failed: ' + (err?.reason || err?.message || err));
    }
  }

  async function refreshTokensOfOwner() {
    if (!contract || !signer) return;
    tokensDiv.textContent = 'Loading...';
    try {
      const addr = await signer.getAddress();
      const tokens = await contract.getTokensOfOwner(addr);
      tokensDiv.innerHTML = '';
      if (tokens.length === 0) tokensDiv.textContent = 'No tokens owned yet.';
      for (const t of tokens) {
        const id = t.toString ? t.toString() : String(t);
        const row = document.createElement('div');
        row.textContent = 'Token #' + id + ' — ';
        const btn = document.createElement('button');
        btn.textContent = 'View metadata';
        btn.onclick = async () => {
          try {
            const uri = await contract.tokenURI(id);
            tokenURIOutput.textContent = uri;
            renderPreviewFromTokenURI(uri);
          } catch (e) {
            tokenURIOutput.textContent = 'Failed to fetch tokenURI: ' + (e?.reason || e?.message || e);
          }
        };
        row.appendChild(btn);
        tokensDiv.appendChild(row);
      }
    } catch (err) {
      console.error(err);
      tokensDiv.textContent = 'Error: ' + err?.message || err;
    }
  }

  async function getTokenURIHandler() {
    if (!contract) return alert('Connect first');
    const id = Number(tokenIdInput.value || '0');
    if (id <= 0) return alert('Enter token id');
    try {
      const uri = await contract.tokenURI(id);
      tokenURIOutput.textContent = uri;
      renderPreviewFromTokenURI(uri);
    } catch (err) {
      tokenURIOutput.textContent = 'Failed: ' + (err?.reason || err?.message || err);
    }
  }

  // Render preview: parse data:application/json;base64,<b64-json>
  function renderPreviewFromTokenURI(tokenURI) {
    if (!tokenURI) return;
    try {
      // tokenURI expected format: data:application/json;base64,<base64json>
      const prefix = 'data:application/json;base64,';
      if (!tokenURI.startsWith(prefix)) {
        metadataInfo.textContent = 'Unsupported tokenURI format';
        imagePreview.style.display = 'none';
        return;
      }
      const b64 = tokenURI.slice(prefix.length);
      const jsonStr = atob(b64);
      const obj = JSON.parse(jsonStr);
      metadataInfo.innerHTML = '';
      if (obj.name) metadataInfo.innerHTML += '<div><strong>' + escapeHtml(obj.name) + '</strong></div>';
      if (obj.description) metadataInfo.innerHTML += '<div>' + escapeHtml(obj.description) + '</div>';

      const image = obj.image;
      if (!image) {
        imagePreview.style.display = 'none';
        return;
      }

      // If image is a data URI (SVG), set it directly as src
      imagePreview.src = image;
      imagePreview.style.display = 'block';
    } catch (e) {
      metadataInfo.textContent = 'Failed to parse tokenURI: ' + (e?.message || e);
      imagePreview.style.display = 'none';
    }
  }

  function escapeHtml(unsafe) {
    return unsafe
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  connectBtn.onclick = connect;
  mintBtn.onclick = mint;
  refreshTokens.onclick = refreshTokensOfOwner;
  getTokenURI.onclick = getTokenURIHandler;

  // auto-fill contract address if developer set it
  if (CONTRACT_ADDRESS) setContractAddress(CONTRACT_ADDRESS);
})();
