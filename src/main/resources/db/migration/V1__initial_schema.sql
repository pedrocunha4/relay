
CREATE TABLE subscriptions (
                               id UUID PRIMARY KEY,
                               name VARCHAR(120) NOT NULL,
                               event_type VARCHAR(150) NOT NULL,
                               target_url VARCHAR(2048) NOT NULL,
                               is_active BOOLEAN NOT NULL DEFAULT TRUE,
                               created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                               updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                               CONSTRAINT chk_subscription_name
                                   CHECK (length(trim(name)) BETWEEN 1 AND 120),

                               CONSTRAINT chk_subscription_event_type
                                   CHECK (
                                       event_type ~
                                       '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
)
    );

CREATE INDEX idx_subscriptions_event_type_active
    ON subscriptions (event_type, is_active);


CREATE TABLE events (
                        id UUID PRIMARY KEY,
                        event_type VARCHAR(150) NOT NULL,
                        payload JSONB NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                        CONSTRAINT chk_event_type
                            CHECK (
                                event_type ~
                                '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
),

    CONSTRAINT chk_event_payload
        CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX idx_events_created_at
    ON events (created_at);


CREATE TABLE deliveries (
                            id UUID PRIMARY KEY,
                            event_id UUID NOT NULL REFERENCES events(id),
                            subscription_id UUID NOT NULL REFERENCES subscriptions(id),
                            target_url VARCHAR(2048) NOT NULL,

                            status VARCHAR(20) NOT NULL DEFAULT 'PENDING',

                            http_status_code INTEGER,
                            response_body TEXT,
                            error_message TEXT,
                            latency_ms BIGINT,

                            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                            started_at TIMESTAMPTZ,
                            completed_at TIMESTAMPTZ,

                            CONSTRAINT uq_event_subscription
                                UNIQUE (event_id, subscription_id),

                            CONSTRAINT chk_delivery_status
                                CHECK (
                                    status IN (
                                               'PENDING',
                                               'PROCESSING',
                                               'SUCCEEDED',
                                               'FAILED'
                                        )
                                    ),

                            CONSTRAINT chk_delivery_http_status
                                CHECK (
                                    http_status_code IS NULL
                                        OR http_status_code BETWEEN 100 AND 599
                                    ),

                            CONSTRAINT chk_delivery_latency
                                CHECK (latency_ms IS NULL OR latency_ms >= 0),

                            CONSTRAINT chk_delivery_lifecycle
                                CHECK (
                                    (
                                        status = 'PENDING'
                                            AND started_at IS NULL
                                            AND completed_at IS NULL
                                            AND http_status_code IS NULL
                                        )
                                        OR
                                    (
                                        status = 'PROCESSING'
                                            AND started_at IS NOT NULL
                                            AND completed_at IS NULL
                                        )
                                        OR
                                    (
                                        status = 'SUCCEEDED'
                                            AND started_at IS NOT NULL
                                            AND completed_at IS NOT NULL
                                            AND http_status_code BETWEEN 200 AND 299
                                        )
                                        OR
                                    (
                                        status = 'FAILED'
                                            AND started_at IS NOT NULL
                                            AND completed_at IS NOT NULL
                                            AND (
                                            http_status_code IS NOT NULL
                                                OR error_message IS NOT NULL
                                            )
                                        )
                                    )
);

CREATE INDEX idx_deliveries_event_id
    ON deliveries (event_id);

CREATE INDEX idx_deliveries_subscription_id
    ON deliveries (subscription_id);

CREATE INDEX idx_deliveries_status_created
    ON deliveries (status, created_at);
