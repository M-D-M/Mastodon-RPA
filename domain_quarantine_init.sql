CREATE TABLE domain_quarantine (
    domain VARCHAR UNIQUE NOT NULL
    , created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE OR REPLACE FUNCTION check_new_user_and_quarantine_if_necessary()
    RETURNS trigger AS
$BODY$
DECLARE
    SEARCH_INTERVAL TIMESTAMP := (now() - INTERVAL '1 HOUR');
    SAFE_INTERVAL TIMESTAMP := (now() - INTERVAL '7 DAYS');
BEGIN
    IF NEW.domain NOT IN (
        SELECT DISTINCT domain
            FROM accounts 
            WHERE (domain NOT IN (
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
    ) THEN
        INSERT INTO domain_quarantine (domain, created_at)
            VALUES (NEW.domain, now());

        INSERT INTO domain_blocks 
            (domain, created_at, updated_at, severity, reject_media, reject_reports)
            VALUES (NEW.domain, now(), now(), 1, 'f', 'f');
    END IF;
END;
$BODY$

CREATE TRIGGER check_new_user AFTER INSERT 
    ON accounts 
    FOR EACH ROW
    EXECUTE PROCEDURE check_new_user_and_quarantine_if_necessary();