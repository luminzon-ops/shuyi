const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

const ROOT = __dirname;
const STORAGE = path.join(ROOT, 'storage');
const CONTENT = path.join(STORAGE, 'content');
const RUNTIME = path.join(STORAGE, 'runtime');
const CLIENT_CONTENT = path.join(ROOT, '..', 'shuyi_playland', 'data', 'content');

const FILES = [
  'grades.json',
  'modules.json',
  'knowledge_points.json',
  'levels.json',
  'questions.json',
  'growth_rules.json',
  'task_rules.json',
  'reward_rules.json',
  'star_rules.json',
  'resource_map.json'
];

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function ensureBootstrap() {
  ensureDir(STORAGE);
  ensureDir(CONTENT);
  ensureDir(RUNTIME);
  ensureDir(CLIENT_CONTENT);
  for (const file of FILES) {
    const adminPath = path.join(CONTENT, file);
    const clientPath = path.join(CLIENT_CONTENT, file);
    if (!fs.existsSync(adminPath) && fs.existsSync(clientPath)) {
      fs.copyFileSync(clientPath, adminPath);
    }
    if (!fs.existsSync(adminPath)) {
      fs.writeFileSync(adminPath, file.endsWith('.json') ? '[]' : '{}');
    }
  }
  if (!fs.existsSync(path.join(RUNTIME, 'analytics.json'))) {
    fs.writeFileSync(path.join(RUNTIME, 'analytics.json'), JSON.stringify({
      exports: [],
      question_count: 0,
      wrong_question_hotspots: [],
      module_breakdown: []
    }, null, 2));
  }
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
}

function contentPath(name) {
  return path.join(CONTENT, name);
}

function refreshAnalytics() {
  const grades = readJson(contentPath('grades.json'));
  const modules = readJson(contentPath('modules.json'));
  const kps = readJson(contentPath('knowledge_points.json'));
  const levels = readJson(contentPath('levels.json'));
  const questions = readJson(contentPath('questions.json'));

  const wrong_question_hotspots = kps.map(kp => ({
    knowledge_point_id: kp.id,
    knowledge_point_name: kp.name,
    question_count: questions.filter(q => q.knowledge_point_id === kp.id).length
  })).sort((a, b) => b.question_count - a.question_count).slice(0, 10);

  const module_breakdown = modules.map(module => ({
    module_id: module.id,
    module_name: module.name,
    knowledge_point_count: kps.filter(k => k.module_id === module.id).length,
    level_count: levels.filter(l => {
      const kp = kps.find(k => k.id === l.knowledge_point_id);
      return kp && kp.module_id === module.id;
    }).length,
    question_count: questions.filter(q => q.module_id === module.id).length
  }));

  writeJson(path.join(RUNTIME, 'analytics.json'), {
    exports: readJson(path.join(RUNTIME, 'analytics.json')).exports || [],
    grade_count: grades.length,
    module_count: modules.length,
    knowledge_point_count: kps.length,
    level_count: levels.length,
    question_count: questions.length,
    wrong_question_hotspots,
    module_breakdown
  });
}

ensureBootstrap();
refreshAnalytics();

app.get('/api/content/:file', (req, res) => {
  const file = req.params.file;
  if (!FILES.includes(file)) return res.status(404).json({ error: 'Unknown content file' });
  res.json(readJson(contentPath(file)));
});

app.put('/api/content/:file', (req, res) => {
  const file = req.params.file;
  if (!FILES.includes(file)) return res.status(404).json({ error: 'Unknown content file' });
  writeJson(contentPath(file), req.body);
  refreshAnalytics();
  res.json({ ok: true, file });
});

app.get('/api/dashboard', (_req, res) => {
  res.json(readJson(path.join(RUNTIME, 'analytics.json')));
});

app.post('/api/export/client-content', (_req, res) => {
  for (const file of FILES) {
    fs.copyFileSync(contentPath(file), path.join(CLIENT_CONTENT, file));
  }
  const analyticsPath = path.join(RUNTIME, 'analytics.json');
  const analytics = readJson(analyticsPath);
  analytics.exports = analytics.exports || [];
  analytics.exports.unshift({ exported_at: new Date().toISOString(), target: CLIENT_CONTENT });
  writeJson(analyticsPath, analytics);
  res.json({ ok: true, message: 'Exported content to Godot client data/content directory.' });
});

app.use(express.static(path.join(ROOT, 'public')));

const PORT = 3131;
app.listen(PORT, () => {
  console.log(`Shuyi admin running at http://localhost:${PORT}`);
});
