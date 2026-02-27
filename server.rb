#!/usr/bin/env ruby
# ─────────────────────────────────────────────────────────────────────────────
# MigraineLog Backend — Ruby WEBrick + SQLite3
# No external gems needed; uses Ruby's built-in webrick and the pre-installed
# sqlite3 gem that ships with macOS system Ruby.
#
# Usage:  ruby server.rb
# API:    http://localhost:4567/api/entries
# ─────────────────────────────────────────────────────────────────────────────

require 'webrick'
require 'sqlite3'
require 'json'
require 'securerandom'

PORT     = (ENV['PORT'] || 4567).to_i
DB_PATH  = File.join(File.dirname(__FILE__), 'migraine.db')

# ── Database setup ────────────────────────────────────────────────────────────
DB = SQLite3::Database.new(DB_PATH)
DB.results_as_hash = true

DB.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS entries (
    id          TEXT PRIMARY KEY,
    date        TEXT NOT NULL,
    severity    INTEGER NOT NULL DEFAULT 3,
    duration    REAL    NOT NULL DEFAULT 4,
    location    TEXT    DEFAULT 'Left temple',
    notes       TEXT    DEFAULT '',
    triggers    TEXT    DEFAULT '[]',
    symptoms    TEXT    DEFAULT '[]',
    medications TEXT    DEFAULT '[]',
    created_at  TEXT    DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
  );
SQL

# ── Helpers ───────────────────────────────────────────────────────────────────
def uid
  SecureRandom.hex(4)
end

def row_to_entry(row)
  {
    id:          row['id'],
    date:        row['date'],
    severity:    row['severity'].to_i,
    duration:    row['duration'].to_f,
    location:    row['location'] || '',
    notes:       row['notes']    || '',
    triggers:    JSON.parse(row['triggers']    || '[]'),
    symptoms:    JSON.parse(row['symptoms']    || '[]'),
    medications: JSON.parse(row['medications'] || '[]'),
  }
end

def all_entries
  DB.execute("SELECT * FROM entries ORDER BY date DESC").map { |r| row_to_entry(r) }
end

def find_entry(id)
  # WEBrick gives req.path as ASCII-8BIT; SQLite3 needs UTF-8 for string matching
  id = id.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
  row = DB.execute("SELECT * FROM entries WHERE id = ?", [id]).first
  row ? row_to_entry(row) : nil
end

def insert_entry(e)
  id = e['id'] || uid
  DB.execute(
    "INSERT OR REPLACE INTO entries (id,date,severity,duration,location,notes,triggers,symptoms,medications) VALUES (?,?,?,?,?,?,?,?,?)",
    [
      id,
      e['date'],
      e['severity'].to_i,
      e['duration'].to_f,
      e['location'] || '',
      e['notes']    || '',
      (e['triggers']    || []).to_json,
      (e['symptoms']    || []).to_json,
      (e['medications'] || []).to_json,
    ]
  )
  find_entry(id)
end

def update_entry(id, e)
  # Ensure UTF-8 encoding for the WHERE id = ? comparison
  id = id.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
  DB.execute(
    "UPDATE entries SET date=?,severity=?,duration=?,location=?,notes=?,triggers=?,symptoms=?,medications=? WHERE id=?",
    [
      e['date'],
      e['severity'].to_i,
      e['duration'].to_f,
      e['location'] || '',
      e['notes']    || '',
      (e['triggers']    || []).to_json,
      (e['symptoms']    || []).to_json,
      (e['medications'] || []).to_json,
      id
    ]
  )
  find_entry(id)
end

def delete_entry(id)
  # Ensure UTF-8 encoding for the WHERE id = ? comparison
  id = id.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
  DB.execute("DELETE FROM entries WHERE id = ?", [id])
end

# ── JSON response helper ──────────────────────────────────────────────────────
def json_response(res, data, status: 200)
  res.status = status
  res['Content-Type']                = 'application/json'
  res['Access-Control-Allow-Origin'] = '*'
  res['Access-Control-Allow-Methods']= 'GET, POST, PUT, DELETE, OPTIONS'
  res['Access-Control-Allow-Headers']= 'Content-Type'
  res.body = data.to_json
end

def error_response(res, message, status: 400)
  json_response(res, {error: message}, status: status)
end

def read_json_body(req)
  body = req.body || ''
  return {} if body.strip.empty?
  JSON.parse(body)
rescue JSON::ParserError
  {}
end

# ── Servlet: handles ALL routes with full path matching ───────────────────────
# Mounted at '/' so WEBrick never strips any prefix — req.path is always the
# full path like /api/entries/abc123
class AppServlet < WEBrick::HTTPServlet::AbstractServlet

  def do_OPTIONS(req, res)
    res.status = 204
    res['Access-Control-Allow-Origin']  = '*'
    res['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res.body = ''
  end

  def do_GET(req, res)
    path = req.path

    # Serve HTML app
    if path == '/' || path == '/index.html'
      html_path = File.join(File.dirname(__FILE__), 'migraine-tracker.html')
      if File.exist?(html_path)
        res['Content-Type'] = 'text/html'
        res.body = File.read(html_path)
      else
        res.status = 404
        res.body   = '<h1>migraine-tracker.html not found</h1>'
      end
      return
    end

    # Health check
    if path == '/api/health'
      json_response(res, {status: 'ok', entries: DB.execute("SELECT COUNT(*) FROM entries").first[0].to_i})
      return
    end

    # List all entries
    if path == '/api/entries' || path == '/api/entries/'
      json_response(res, all_entries)
      return
    end

    # Get single entry
    if (m = path.match(%r{^/api/entries/([^/]+)$}))
      entry = find_entry(m[1])
      if entry
        json_response(res, entry)
      else
        error_response(res, 'Entry not found', status: 404)
      end
      return
    end

    error_response(res, 'Not found', status: 404)
  end

  def do_POST(req, res)
    path = req.path
    if path == '/api/entries' || path == '/api/entries/'
      data  = read_json_body(req)
      entry = insert_entry(data)
      json_response(res, entry, status: 201)
      return
    end
    error_response(res, 'Not found', status: 404)
  end

  def do_PUT(req, res)
    path = req.path
    if (m = path.match(%r{^/api/entries/([^/]+)$}))
      id = m[1]
      if find_entry(id).nil?
        error_response(res, 'Entry not found', status: 404)
        return
      end
      data  = read_json_body(req)
      entry = update_entry(id, data)
      json_response(res, entry)
      return
    end
    error_response(res, 'Not found', status: 404)
  end

  def do_DELETE(req, res)
    path = req.path
    if (m = path.match(%r{^/api/entries/([^/]+)$}))
      id = m[1]
      if find_entry(id).nil?
        error_response(res, 'Entry not found', status: 404)
        return
      end
      delete_entry(id)
      json_response(res, {deleted: id})
      return
    end
    error_response(res, 'Not found', status: 404)
  end

end

# ── Start server ──────────────────────────────────────────────────────────────
log_file = File.open(File.join(File.dirname(__FILE__), 'server.log'), 'a')
logger   = WEBrick::Log.new(log_file, WEBrick::Log::WARN)

server = WEBrick::HTTPServer.new(
  Port:            PORT,
  Logger:          logger,
  AccessLog:       [[log_file, WEBrick::AccessLog::COMBINED_LOG_FORMAT]],
  DoNotReverseLookup: true
)

# Mount servlet at root — no prefix stripping, req.path is always the full path
server.mount('/', AppServlet)

trap('INT')  { server.shutdown }
trap('TERM') { server.shutdown }

puts ""
puts "  ╔══════════════════════════════════════════╗"
puts "  ║        MigraineLog Server Started        ║"
puts "  ╠══════════════════════════════════════════╣"
puts "  ║  URL:      http://localhost:#{PORT}         ║"
puts "  ║  Database: #{File.basename(DB_PATH)}                    ║"
puts "  ║  Press Ctrl+C to stop                    ║"
puts "  ╚══════════════════════════════════════════╝"
puts ""

server.start
