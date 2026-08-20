#!/usr/bin/env ruby

# Convert the multi-tool YAML input into a fully populated GitHub Actions matrix.

require 'json'
require 'yaml'

DEFAULT_TAG_PATTERN =
  '^v([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?)$'

DEFAULTS = {
  'source' => 'github',
  'tag-pattern' => DEFAULT_TAG_PATTERN,
  'version-pattern' => '',
  'include-prereleases' => 'false',
  'channels' => '',
  'subdirs' => '',
  'docker-tag' => '1.1.0',
  'issue-labels' => ''
}.freeze

REQUIRED_KEYS = %w[repository issue-repository package].freeze
ALLOWED_KEYS = (REQUIRED_KEYS + DEFAULTS.keys).freeze
LIST_KEYS = %w[channels subdirs issue-labels].freeze
REPOSITORY_PATTERN = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}
DOCKER_TAG_PATTERN = /\A[A-Za-z0-9_.-]+\z/

def fail_input(message)
  warn "Invalid tools YAML: #{message}"
  exit 1
end

def string_value(value, item_number, key, allow_empty: true)
  unless value.is_a?(String)
    fail_input "item #{item_number} '#{key}' must be a string"
  end
  if !allow_empty && value.strip.empty?
    fail_input "item #{item_number} '#{key}' must not be empty"
  end

  value
end

def list_value(value, item_number, key)
  return value if value.is_a?(String)
  unless value.is_a?(Array) && value.all? { |entry| entry.is_a?(String) }
    fail_input "item #{item_number} '#{key}' must be a string or a list of strings"
  end

  value.join("\n")
end

begin
  document = YAML.safe_load($stdin.read, permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::Exception => e
  fail_input "could not parse YAML (#{e.message.lines.first.strip})"
end

tools = if document.is_a?(Array)
          document
        elsif document.is_a?(Hash)
          unknown_top_level_keys = document.keys - ['tools']
          unless unknown_top_level_keys.empty?
            fail_input "unknown top-level key(s): #{unknown_top_level_keys.join(', ')}"
          end
          document['tools']
        end

fail_input "expected a list or a top-level 'tools' list" unless tools.is_a?(Array)
fail_input 'the tools list must not be empty' if tools.empty?

matrix = tools.each_with_index.map do |item, index|
  item_number = index + 1
  fail_input "item #{item_number} must be a mapping" unless item.is_a?(Hash)
  fail_input "item #{item_number} keys must be strings" unless item.keys.all?(String)

  unknown_keys = item.keys - ALLOWED_KEYS
  unless unknown_keys.empty?
    fail_input "item #{item_number} has unknown key(s): #{unknown_keys.join(', ')}"
  end

  REQUIRED_KEYS.each do |key|
    fail_input "item #{item_number} is missing '#{key}'" unless item.key?(key)
  end

  normalized = DEFAULTS.merge(item)

  REQUIRED_KEYS.each do |key|
    normalized[key] = string_value(normalized[key], item_number, key, allow_empty: false)
  end
  %w[tag-pattern version-pattern].each do |key|
    normalized[key] = string_value(normalized[key], item_number, key)
  end
  LIST_KEYS.each do |key|
    normalized[key] = list_value(normalized[key], item_number, key)
  end

  source = string_value(normalized['source'], item_number, 'source', allow_empty: false)
  unless %w[github conda].include?(source)
    fail_input "item #{item_number} 'source' must be github or conda"
  end

  prereleases = normalized['include-prereleases']
  prereleases = prereleases.to_s if prereleases == true || prereleases == false
  unless %w[true false].include?(prereleases)
    fail_input "item #{item_number} 'include-prereleases' must be true or false"
  end
  normalized['include-prereleases'] = prereleases

  docker_tag = string_value(
    normalized['docker-tag'], item_number, 'docker-tag', allow_empty: false
  )
  unless DOCKER_TAG_PATTERN.match?(docker_tag)
    fail_input "item #{item_number} has invalid 'docker-tag'"
  end

  %w[repository issue-repository].each do |key|
    repository = normalized[key]
    unless REPOSITORY_PATTERN.match?(repository)
      fail_input "item #{item_number} '#{key}' must use owner/repository format"
    end
  end

  normalized
end

puts JSON.generate('include' => matrix)
