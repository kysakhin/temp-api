CREATE TABLE IF NOT EXISTS bonds (
    isin             VARCHAR(12)    PRIMARY KEY,
    bond_name        TEXT           NOT NULL,
    rating           VARCHAR(20),
    bond_yield       DECIMAL(6, 2),
    min_investment   BIGINT,
    payout_frequency VARCHAR(30),
    logo_url         TEXT,
    detail_url       TEXT,
    tenure           DECIMAL(6, 2)  NOT NULL,
    maturity_date    DATE,
    color            VARCHAR(7)
);
