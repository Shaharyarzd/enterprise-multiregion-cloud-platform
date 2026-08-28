CREATE TABLE patients (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    synthetic_id text NOT NULL UNIQUE CHECK (synthetic_id LIKE 'patient-demo-%')
);

CREATE TABLE appointments (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    synthetic_id text NOT NULL UNIQUE CHECK (synthetic_id LIKE 'apt-demo-%'),
    patient_id bigint NOT NULL REFERENCES patients(id),
    status text NOT NULL CHECK (status IN ('scheduled', 'completed', 'cancelled'))
);

INSERT INTO patients (synthetic_id)
VALUES ('patient-demo-001'), ('patient-demo-002');

INSERT INTO appointments (synthetic_id, patient_id, status)
SELECT 'apt-demo-001', id, 'scheduled' FROM patients WHERE synthetic_id = 'patient-demo-001';

INSERT INTO appointments (synthetic_id, patient_id, status)
SELECT 'apt-demo-002', id, 'completed' FROM patients WHERE synthetic_id = 'patient-demo-002';
