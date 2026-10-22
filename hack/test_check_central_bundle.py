"""Self-test for check_central_bundle.py.

The checker is the only thing standing between a malformed bundle and a
rejected release. Central's own rejection ("Bundle has content that does NOT
have a .pom file: io/kcl-lang/kcl-lib") names the coordinate but not the file
that upset it, and it only arrives after the upload has been rejected, so a
checker that quietly reports "ok" over a broken bundle is worse than no
checker at all.

Every claim the checker makes is therefore verified here by breaking a bundle
on purpose and asserting the report names the right file. The control case
comes first: a bundle that has everything Central asks for has to come back
clean, because a checker that reports problems for a good bundle gets ignored
and then catches nothing.

Run with:

    python3 -m pytest hack/test_check_central_bundle.py -v
"""

import subprocess
import sys
import zipfile
from pathlib import Path

import pytest

from check_central_bundle import check_bundle

CHECKER = Path(__file__).resolve().parent / 'check_central_bundle.py'

# The group is a dotted id, so it spans two path segments. A checker that
# splits the coordinate by a fixed depth mis-reads every layout that looks
# like this one, which is why the fixtures below use it.
GROUP = 'io/kcl-lang'
ARTIFACT = 'kcl-lib'
VERSION = '0.13.2'
PREFIX = f'{GROUP}/{ARTIFACT}/{VERSION}'


def good_files():
    """The files Central requires for one coordinate."""
    files = {}
    for suffix in ('.pom', '.jar', '-sources.jar', '-javadoc.jar'):
        name = f'{ARTIFACT}-{VERSION}{suffix}'
        files[f'{PREFIX}/{name}'] = b'content'
        files[f'{PREFIX}/{name}.md5'] = b'content'
    return files


def write_bundle(tmp_path, files):
    path = tmp_path / 'central-bundle.zip'
    with zipfile.ZipFile(path, 'w') as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    return path


def run_checker(*args):
    return subprocess.run(
        [sys.executable, str(CHECKER), *args],
        capture_output=True,
        text=True,
    )


def test_a_complete_bundle_has_no_problems(tmp_path):
    assert check_bundle(write_bundle(tmp_path, good_files())) == []


@pytest.mark.parametrize(
    'stray',
    [
        # The two files Maven 3.10.0 writes into the plugin's staging
        # directory (MNG-13388), at the levels the plugin's layout puts
        # them on. These two are what actually broke the v0.13.2 release.
        f'{GROUP}/{ARTIFACT}/maven-metadata-local.xml',
        f'{GROUP}/{ARTIFACT}/{VERSION}/_remote.repositories',
        # The staging metadata the plugin is supposed to delete before
        # zipping, kept here as a guard on the plugin's own cleanup.
        f'{GROUP}/{ARTIFACT}/{VERSION}/maven-metadata-central-staging.xml',
        # A lock file, and a file inside a lock directory.
        f'{PREFIX}/{ARTIFACT}-{VERSION}.jar.lock',
        f'{PREFIX}/.locks/{ARTIFACT}-{VERSION}.jar',
    ],
)
def test_resolver_bookkeeping_files_are_reported(tmp_path, stray):
    files = good_files()
    files[stray] = b'content'

    problems = check_bundle(write_bundle(tmp_path, files))

    assert len(problems) == 1
    assert stray in problems[0]


@pytest.mark.parametrize(
    'missing',
    [
        f'{ARTIFACT}-{VERSION}.pom',
        f'{ARTIFACT}-{VERSION}.jar',
        f'{ARTIFACT}-{VERSION}-sources.jar',
        f'{ARTIFACT}-{VERSION}-javadoc.jar',
    ],
)
def test_a_missing_required_file_is_reported(tmp_path, missing):
    files = good_files()
    del files[f'{PREFIX}/{missing}']

    problems = check_bundle(write_bundle(tmp_path, files))

    assert problems == [f'{PREFIX} is missing {missing}']


def test_a_file_outside_its_version_directory_is_reported(tmp_path):
    files = good_files()
    files[f'{PREFIX}/some-other-artifact-1.0.0.jar'] = b'content'

    problems = check_bundle(write_bundle(tmp_path, files))

    assert problems == [
        f'{PREFIX}/some-other-artifact-1.0.0.jar does not match its '
        '<artifact>/<version>/ directory'
    ]


def test_a_file_outside_a_coordinate_directory_is_reported(tmp_path):
    files = good_files()
    files['some-other-artifact-1.0.0.jar'] = b'content'

    problems = check_bundle(write_bundle(tmp_path, files))

    assert problems == [
        'some-other-artifact-1.0.0.jar is not under a '
        '<group>/<artifact>/<version>/ path'
    ]


def test_a_bundle_with_a_stray_and_a_missing_file_reports_both(tmp_path):
    """One broken bundle must not hide the other problem behind the first."""
    files = good_files()
    del files[f'{PREFIX}/{ARTIFACT}-{VERSION}-javadoc.jar']
    files[f'{GROUP}/{ARTIFACT}/maven-metadata-local.xml'] = b'content'

    problems = check_bundle(write_bundle(tmp_path, files))

    assert len(problems) == 2


def test_the_cli_accepts_a_good_bundle(tmp_path):
    bundle = write_bundle(tmp_path, good_files())

    result = run_checker(str(bundle))

    assert result.returncode == 0
    assert 'is a valid Central bundle' in result.stdout


def test_the_cli_rejects_a_bad_bundle(tmp_path):
    files = good_files()
    files[f'{GROUP}/{ARTIFACT}/maven-metadata-local.xml'] = b'content'
    bundle = write_bundle(tmp_path, files)

    result = run_checker(str(bundle))

    assert result.returncode == 1
    assert 'is not a valid Central bundle' in result.stdout


def test_the_cli_fails_on_a_missing_bundle(tmp_path):
    result = run_checker(str(tmp_path / 'absent.zip'))

    assert result.returncode == 1
    assert 'no bundle at' in result.stdout


def test_the_cli_tolerates_a_missing_bundle_when_optional(tmp_path):
    result = run_checker(str(tmp_path / 'absent.zip'), '--optional')

    assert result.returncode == 0
    assert 'nothing to check' in result.stdout
