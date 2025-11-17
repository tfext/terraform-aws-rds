#!/usr/bin/env python3
import subprocess
import json


def fetch_engine_versions():
  """Fetch DB engine versions from AWS RDS."""
  result = subprocess.run(
    ['aws', 'rds', 'describe-db-engine-versions'],
    capture_output=True,
    text=True,
    check=True
  )
  return json.loads(result.stdout)


def parse_version(version_string):
  """Parse a version string into a list of integers."""
  return [int(x) for x in version_string.split('.') if x.isdigit()]


def compare_versions(current_version, new_version):
  """Compare two version strings, returning True if new_version is greater."""
  current_parts = parse_version(current_version)
  new_parts = parse_version(new_version)
  
  max_len = max(len(current_parts), len(new_parts))
  current_parts += [0] * (max_len - len(current_parts))
  new_parts += [0] * (max_len - len(new_parts))
  
  return new_parts > current_parts


def extract_max_engine_versions(engine_versions_data):
  """Extract unique engines with their maximum major version and parameter group family."""
  engines_dict = {}
  
  for version in engine_versions_data['DBEngineVersions']:
    engine = version['Engine']
    major_version = version.get('MajorEngineVersion', '')
    param_group_family = version.get('DBParameterGroupFamily', '')
    
    if engine not in engines_dict:
      engines_dict[engine] = {'version': major_version, 'param_group_family': param_group_family}
    elif major_version and engines_dict[engine]['version']:
      if compare_versions(engines_dict[engine]['version'], major_version):
        engines_dict[engine] = {'version': major_version, 'param_group_family': param_group_family}
    elif major_version:
      engines_dict[engine] = {'version': major_version, 'param_group_family': param_group_family}
  
  return engines_dict


def print_engine_versions(engines_dict):
  """Print engine versions in sorted order."""
  engines_list = [(engine, data['version'], data['param_group_family']) 
          for engine, data in engines_dict.items()]
  
  for engine, max_version, param_group_family in sorted(engines_list):
    print(f"{engine}: {max_version} (Parameter Group Family: {param_group_family})")


def main():
  """Main entry point for the script."""
  engine_versions_data = fetch_engine_versions()
  engines_dict = extract_max_engine_versions(engine_versions_data)
  print_engine_versions(engines_dict)


if __name__ == '__main__':
  main()
