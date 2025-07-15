// API Redirect Interceptor
// This script should be loaded on pages that might contain old API links
// It intercepts clicks to old API URLs and redirects them properly

(function() {
    'use strict';

    // Mapping of old tag names to new endpoint paths
    const tagMappings = {
        'Fiat-Transfers': 'fiat-transfers',
        'Identity': 'identity',
        'Transfers': 'transfers',
        'Deposit-Addresses': 'deposit-addresses',
        'Profiles': 'profiles',
        'Settlement': 'settlement',
        'Stablecoin-Conversion': 'stablecoin-conversion',
        'Orders': 'orders',
        'Market-Data': 'market-data',
        'Events': 'events',
        'Crypto-Deposits': 'crypto-deposits',
        'Crypto-Withdrawals': 'crypto-withdrawals',
        'Sandbox-Deposits': 'sandbox-deposits',
        'Sandbox-Identity': 'sandbox-identity',
        'Sandbox-Fiat-Transfers': 'sandbox-fiat-transfers',
        'Quotes': 'quotes',
        'Quote-Executions': 'quote-executions',
        'Pricing': 'pricing',
        'Statements': 'statements',
        'Payments': 'payments',
        'Monitoring-Addresses': 'monitoring-addresses',
        'Tax-Forms': 'tax-forms',
        'Limits': 'limits',
        'Fees': 'fees',
        'Internal-Transfers': 'internal-transfers',
        'Paxos-Transfers': 'paxos-transfers',
        'Accounts': 'accounts',
        'Account-Members': 'account-members',
        'Institution-Members': 'institution-members',
        'Identity-Documents': 'identity-documents'
    };

    // Mapping of operation names to endpoint filenames
    const operationMappings = {
        // Fiat Transfers
        'ListFiatAccounts': 'list-fiat-accounts',
        'CreateFiatAccount': 'create-fiat-account',
        'GetFiatAccount': 'get-fiat-account',
        'UpdateFiatAccount': 'update-fiat-account',
        'DeleteFiatAccount': 'delete-fiat-account',
        'ListFiatDepositInstructions': 'list-fiat-deposit-instructions',
        'CreateFiatDepositInstructions': 'create-fiat-deposit-instructions',
        'GetFiatDepositInstructions': 'get-fiat-deposit-instructions',
        'CreateFiatWithdrawal': 'create-fiat-withdrawal',
        
        // Identity
        'ListIdentities': 'list-identities',
        'CreateIdentity': 'create-identity',
        'GetIdentity': 'get-identity',
        'UpdateIdentity': 'update-identity',
        
        // Transfers
        'ListTransfers': 'list-transfers',
        'GetTransfer': 'get-transfer',
        
        // Deposit Addresses
        'ListDepositAddresses': 'list-deposit-addresses',
        'CreateDepositAddress': 'create-deposit-address',
        
        // Profiles
        'ListProfiles': 'list-profiles',
        'CreateProfile': 'create-profile',
        'GetProfile': 'get-profile',
        'UpdateProfile': 'update-profile',
        'DeactivateProfile': 'deactivate-profile',
        'ListProfileBalances': 'list-profile-balances',
        'GetProfileBalance': 'get-profile-balance',
        
        // Settlement
        'ListTransactions': 'list-transactions',
        'CreateTransaction': 'create-transaction',
        'GetTransaction': 'get-transaction',
        'CancelTransaction': 'cancel-transaction',
        'AffirmTransaction': 'affirm-transaction',
        
        // Stablecoin Conversion
        'ListStablecoinConversions': 'list-stablecoin-conversions',
        'CreateStablecoinConversion': 'create-stablecoin-conversion',
        'GetStablecoinConversion': 'get-stablecoin-conversion',
        'CancelStablecoinConversion': 'cancel-stablecoin-conversion',
        
        // Orders
        'ListOrders': 'list-orders',
        'CreateOrder': 'create-order',
        'GetOrder': 'get-order',
        'CancelOrder': 'cancel-order',
        'ListExecutions': 'list-executions',
        
        // Market Data
        'ListMarkets': 'list-markets',
        'GetOrderBook': 'get-order-book',
        'ListRecentExecutions': 'list-recent-executions',
        'GetTicker': 'get-ticker',
        
        // Events
        'ListEvents': 'list-events',
        'GetEvent': 'get-event',
        
        // Additional mappings...
        'UpdateCryptoDeposit': 'update-crypto-deposit',
        'RejectCryptoDeposit': 'reject-crypto-deposit',
        'CreateCryptoWithdrawal': 'create-crypto-withdrawal',
        'CreateSandboxDeposit': 'create-sandbox-deposit',
        'SandboxSetIdentityStatus': 'sandbox-set-identity-status',
        'InitiateSandboxFiatDeposit': 'initiate-sandbox-fiat-deposit',
        'ListQuotes': 'list-quotes',
        'ListQuoteExecutions': 'list-quote-executions',
        'CreateQuoteExecution': 'create-quote-execution',
        'GetQuoteExecution': 'get-quote-execution'
    };

    function parseApiFragment(fragment) {
        console.log('Parsing fragment:', fragment);
        
        if (!fragment || !fragment.includes('tag/')) {
            return '/api-reference/introduction';
        }

        // Extract tag and operation
        const tagMatch = fragment.match(/tag\/([^\/]+)/);
        const operationMatch = fragment.match(/operation\/([^\/\?&#]+)/);
        
        if (!tagMatch) {
            return '/api-reference/introduction';
        }

        const tag = tagMatch[1];
        const operation = operationMatch ? operationMatch[1] : null;
        
        console.log('Extracted tag:', tag, 'operation:', operation);

        // Map tag to endpoint path
        const endpointPath = tagMappings[tag];
        if (!endpointPath) {
            console.log('No mapping found for tag:', tag);
            return '/api-reference/introduction';
        }

        let targetUrl = `/api-reference/endpoints/${endpointPath}`;

        // If we have an operation, try to map it to specific endpoint
        if (operation && operationMappings[operation]) {
            targetUrl += `/${operationMappings[operation]}`;
        }

        console.log('Mapped to:', targetUrl);
        return targetUrl;
    }

    function interceptApiLinks() {
        // Check if we're already on a redirected page
        if (window.location.pathname.includes('/api-reference/')) {
            return;
        }

        // Check current URL for API fragments
        const hash = window.location.hash.replace('#', '');
        if (hash && (hash.includes('tag/') || hash.includes('api/v2'))) {
            const targetUrl = parseApiFragment(hash);
            console.log('Redirecting current page from', window.location.href, 'to', targetUrl);
            window.location.href = targetUrl;
            return;
        }

        // Intercept clicks on links
        document.addEventListener('click', function(e) {
            const link = e.target.closest('a');
            if (!link) return;

            const href = link.href;
            
            // Check for old API URLs
            if (href.includes('api/v2') || href.includes('#tag/')) {
                e.preventDefault();
                
                let fragment = '';
                if (href.includes('#')) {
                    fragment = href.split('#')[1];
                } else if (href.includes('api/v2')) {
                    // Handle cases where the fragment might be in the pathname
                    const url = new URL(href, window.location.origin);
                    fragment = url.pathname.replace('/api/v2', '') + url.hash.replace('#', '');
                }
                
                const targetUrl = parseApiFragment(fragment);
                console.log('Intercepted link click:', href, '→', targetUrl);
                window.location.href = targetUrl;
            }
        });
    }

    // Run when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', interceptApiLinks);
    } else {
        interceptApiLinks();
    }

    // Also run on hash changes
    window.addEventListener('hashchange', function() {
        const hash = window.location.hash.replace('#', '');
        if (hash && hash.includes('tag/')) {
            const targetUrl = parseApiFragment(hash);
            console.log('Hash change redirect:', hash, '→', targetUrl);
            window.location.href = targetUrl;
        }
    });

    // Make the function globally available for testing
    window.parseApiFragment = parseApiFragment;
})();