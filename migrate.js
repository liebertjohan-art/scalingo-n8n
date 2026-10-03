const { Client } = require("pg");

const raw = process.env.SCALINGO_POSTGRESQL_URL || process.env.DATABASE_URL;
if (!raw || raw.startsWith("$")) {
  console.log("[Migration] No database URL found, skipping.");
  process.exit(0);
}

const client = new Client({
  connectionString: raw,
  ssl: { rejectUnauthorized: false }
});

const sql = `
CREATE SCHEMA IF NOT EXISTS rag;

CREATE TABLE IF NOT EXISTS rag.domains (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rag.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_id TEXT REFERENCES rag.domains(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tsv tsvector GENERATED ALWAYS AS (to_tsvector('english', title || ' ' || content)) STORED,
    metadata JSONB DEFAULT '{}',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rag_documents_tsv ON rag.documents USING GIN(tsv);
CREATE INDEX IF NOT EXISTS idx_rag_documents_domain ON rag.documents(domain_id);

CREATE TABLE IF NOT EXISTS rag.entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_id TEXT REFERENCES rag.domains(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    summary TEXT,
    attributes JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_rag_entities_name ON rag.entities(name);
CREATE INDEX IF NOT EXISTS idx_rag_entities_domain ON rag.entities(domain_id);

CREATE TABLE IF NOT EXISTS rag.relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES rag.entities(id) ON DELETE CASCADE,
    target_id UUID REFERENCES rag.entities(id) ON DELETE CASCADE,
    relation_type TEXT NOT NULL,
    description TEXT
);

CREATE INDEX IF NOT EXISTS idx_rag_relations_source ON rag.relations(source_id);
CREATE INDEX IF NOT EXISTS idx_rag_relations_target ON rag.relations(target_id);

INSERT INTO rag.domains (id, name, category) VALUES
  ('campus-general', 'BBAU Campus General', 'administration'),
  ('uiet-cse', 'UIET Computer Science & Engineering', 'academic'),
  ('uiet-ece', 'UIET Electronics & Communication', 'academic'),
  ('uiet-mechanical', 'UIET Mechanical Engineering', 'academic'),
  ('uiet-civil', 'UIET Civil Engineering', 'academic'),
  ('uiet-electrical', 'UIET Electrical Engineering', 'academic'),
  ('hostels', 'Hostels & Residential Life', 'facility'),
  ('samarth-exam', 'Samarth Portal & Exam Cell', 'administration'),
  ('scholarships', 'UP & National Scholarships', 'administration')
ON CONFLICT (id) DO NOTHING;
`;

async function run() {
  try {
    await client.connect();
    await client.query(sql);
    console.log("[Migration] RAG schema and tables initialized.");
  } catch (err) {
    console.error("[Migration] Error:", err.message);
  } finally {
    await client.end();
  }
}

run();
