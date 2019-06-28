CREATE TABLE domain_quarantine (
    domain VARCHAR UNIQUE NOT NULL
    , created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
);