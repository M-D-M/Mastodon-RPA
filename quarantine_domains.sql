DO $$
DECLARE
    NEW_ACCOUNT RECORD;
    QUARANTINED_DOMAIN RECORD;
    SEARCH_INTERVAL TIMESTAMP := (now() - INTERVAL '7 DAYS');
    SAFE_INTERVAL TIMESTAMP := (now() - INTERVAL '7 DAYS');
BEGIN

    /*******************************************************************
        Quarantine new domains found in past SEARCH_INTERVAL hours,
        that 
            1) aren't already quarantined
            2) that don't have existing accounts present already that are older than SAFE_INTERVAL days
            3) that aren't already blocked
    *******************************************************************/
    FOR NEW_ACCOUNT IN
        SELECT DISTINCT domain
            FROM accounts 
            WHERE (created_at > SEARCH_INTERVAL)
                AND (domain NOT IN (
                    SELECT domain from domain_quarantine
                ))
                AND (domain NOT IN (
                    SELECT DISTINCT domain
                    FROM accounts
                    WHERE created_at < SAFE_INTERVAL
                ))
                AND (domain NOT IN (
                    SELECT domain FROM domain_blocks
                ))
    LOOP
        RAISE NOTICE 'Domain "%" has not been quarantined yet.  Doing so now.', NEW_ACCOUNT.domain;

        INSERT INTO domain_quarantine (domain, created_at)
            VALUES (NEW_ACCOUNT.domain, now());

        INSERT INTO domain_blocks 
            (domain, created_at, updated_at, severity, reject_media, reject_reports)
            VALUES (NEW_ACCOUNT.domain, now(), now(), 1, 'f', 'f');
    END LOOP;


    /*******************************************************************
        Perform maintenance on domains in quarantine 
        that have been there longer than SAFE_INTERVAL days
    *******************************************************************/
    FOR QUARANTINED_DOMAIN IN 
        SELECT domain
            FROM domain_quarantine 
            WHERE created_at < SAFE_INTERVAL
    LOOP
        RAISE NOTICE 'Removing % from quarantine...', QUARANTINED_DOMAIN.domain;

        DELETE FROM domain_quarantine
            WHERE domain = QUARANTINED_DOMAIN.domain;

        DELETE FROM domain_blocks
            WHERE domain = QUARANTINED_DOMAIN.domain;
    END LOOP;
END; $$