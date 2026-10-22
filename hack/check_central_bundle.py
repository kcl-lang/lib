"""Validate the bundle that central-publishing-maven-plugin sends to Central.

Central rejects a deployment with "Bundle has content that does NOT have a .pom
file: <group>/<artifact>" when the bundle carries files outside the
<group>/<artifact>/<version>/ layout. Maven 3.10.0 made
LegacyLocalRepositoryManager.overlay() write Resolver bookkeeping files into the
plugin's staging directory (MNG-13388), so `maven-metadata-local.xml` lands at
the artifact level and `_remote.repositories` at the version level. The plugin
only deletes `maven-metadata-central-staging.xml` before zipping, so the strays
end up in the bundle and Central refuses the deployment.

Checking the bundle locally turns that opaque server-side rejection into a
precise, local error before anything is uploaded.
"""

from argparse import ArgumentDefaultsHelpFormatter, ArgumentParser
from pathlib import Path
import sys
import zipfile

# Resolver bookkeeping files that must never reach Central.
STRAY_NAMES = frozenset(
    {
        'maven-metadata-local.xml',
        'maven-metadata-central-staging.xml',
        '_remote.repositories',
    }
)
STRAY_SUFFIXES = ('.lock',)


def is_stray(path: str) -> bool:
    name = path.rsplit('/', 1)[-1]
    return name in STRAY_NAMES or name.endswith(STRAY_SUFFIXES) or '/.locks/' in path


def check_bundle(bundle: Path) -> list[str]:
    """Return the list of problems found in the bundle."""
    problems: list[str] = []
    with zipfile.ZipFile(bundle) as archive:
        names = [n for n in archive.namelist() if not n.endswith('/')]

    strays = sorted(n for n in names if is_stray(n))
    if strays:
        problems.append(
            'the bundle carries Maven Resolver bookkeeping files that Central '
            'rejects ("Bundle has content that does NOT have a .pom file"):\n'
            + '\n'.join(f'    - {n}' for n in strays)
            + '\n  Maven 3.10.0+ writes these into the plugin staging directory '
            '(MNG-13388). central-publishing-maven-plugin >= 0.12.0 removes them '
            'before zipping.'
        )

    # Every file must live in a <group>/<artifact>/<version>/ directory. The
    # group is a dotted id, so it spans several path segments; the artifact and
    # the version are always the last two.
    gavs: dict[str, set[str]] = {}
    for name in names:
        if is_stray(name):
            continue
        parts = name.split('/')
        if len(parts) < 4:
            problems.append(f'{name} is not under a <group>/<artifact>/<version>/ path')
            continue
        artifact, version = parts[-3], parts[-2]
        filename = parts[-1]
        if not filename.startswith(f'{artifact}-{version}'):
            problems.append(
                f'{name} does not match its <artifact>/<version>/ directory'
            )
            continue
        gavs.setdefault('/'.join(parts[:-1]), set()).add(filename)

    # Central requires a POM, a main artifact, sources and javadoc for every
    # coordinate in the bundle.
    for gav, files in sorted(gavs.items()):
        artifact, version = gav.rsplit('/', 2)[-2:]
        for filename in (
            f'{artifact}-{version}.pom',
            f'{artifact}-{version}.jar',
            f'{artifact}-{version}-sources.jar',
            f'{artifact}-{version}-javadoc.jar',
        ):
            if filename not in files:
                problems.append(f'{gav} is missing {filename}')

    return problems


if __name__ == '__main__':
    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter)
    parser.add_argument('bundle', type=Path, help='path to central-bundle.zip')
    parser.add_argument(
        '--optional',
        action='store_true',
        help='exit 0 when the bundle is missing instead of failing',
    )
    args = parser.parse_args()

    if not args.bundle.is_file():
        message = f'no bundle at {args.bundle}'
        if args.optional:
            print(f'warning: {message}, nothing to check')
            sys.exit(0)
        print(f'error: {message}')
        sys.exit(1)

    problems = check_bundle(args.bundle)
    if problems:
        print(f'error: {args.bundle} is not a valid Central bundle:')
        for problem in problems:
            print(f'  - {problem}')
        sys.exit(1)

    print(f'ok: {args.bundle} is a valid Central bundle')
