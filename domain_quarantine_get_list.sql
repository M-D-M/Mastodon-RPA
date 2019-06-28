DO $$
DECLARE
    NEW_ACCOUNT RECORD;
    SEARCH_INTERVAL TIMESTAMP := (now() - INTERVAL '7 DAYS');
    SAFE_INTERVAL TIMESTAMP := (now() - INTERVAL '7 DAYS');
    OUTPUT_LOCATION TEXT := '/tmp/output.csv';
BEGIN
    FOR NEW_ACCOUNT IN
        SELECT DISTINCT domain
            FROM accounts 
            WHERE (created_at > SEARCH_INTERVAL)
                AND (domain NOT IN (
                    SELECT DISTINCT domain
                    FROM accounts
                    WHERE created_at < SAFE_INTERVAL
                ))
    LOOP
        RAISE NOTICE '%', NEW_ACCOUNT.domain;
    END LOOP;
END; $$