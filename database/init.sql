-- CareStream360 Database Initialization

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create indexes for better performance
-- (Django migrations will create the main tables)

-- Function to calculate QoE score
CREATE OR REPLACE FUNCTION calculate_qoe_score(
    latency_ms INTEGER,
    download_speed FLOAT,
    signal_strength INTEGER,
    packet_loss FLOAT
) RETURNS FLOAT AS $$
BEGIN
    RETURN GREATEST(0.0, LEAST(5.0,
        ((200 - GREATEST(0, LEAST(200, latency_ms))) / 200.0 * 1.5) +
        (GREATEST(0, LEAST(100, download_speed)) / 100.0 * 1.5) +
        ((signal_strength + 120) / 80.0 * 1.0) +
        ((10.0 - GREATEST(0, LEAST(10, packet_loss))) / 10.0 * 1.0)
    ));
END;
$$ LANGUAGE plpgsql;

-- Create trigger function for automatic QoE calculation
CREATE OR REPLACE FUNCTION trigger_qoe_calculation()
RETURNS TRIGGER AS $$
BEGIN
    -- This would trigger ML calculation in real implementation
    -- For now, just log the event
    INSERT INTO qoe_prediction_log (session_id, created_at, status)
    VALUES (NEW.session_id, NOW(), 'pending')
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Performance optimization views
CREATE OR REPLACE VIEW session_summary AS
SELECT 
    s.session_id,
    s.customer_id,
    s.start_time,
    s.end_time,
    s.is_active,
    COUNT(nm.id) as metric_count,
    AVG(nm.latency_ms) as avg_latency,
    AVG(nm.download_speed_mbps) as avg_download,
    AVG(nm.signal_strength) as avg_signal,
    MAX(qoe.score) as latest_qoe_score
FROM monitoring_sessiondata s
LEFT JOIN monitoring_networkmetrics nm ON s.id = nm.session_id
LEFT JOIN qoe_qoescore qoe ON s.id = qoe.session_id
GROUP BY s.session_id, s.customer_id, s.start_time, s.end_time, s.is_active;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO carestream;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO carestream;
