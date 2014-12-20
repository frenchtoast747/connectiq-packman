import subprocess
import os
import fnmatch
import sys
import argparse


# path to the SDK directory; *NOT* the bin directory
CONNECT_IQ_SDK_DIR = r'C:\connectiq\connectiq-sdk-win-0.3.0'

script_extension = ''
if os.name == 'nt':
    script_extension = '.bat'

MONKEYC = os.path.join(CONNECT_IQ_SDK_DIR, 'bin', 'monkeyc' + script_extension)
MONKEYDO = os.path.join(CONNECT_IQ_SDK_DIR, 'bin', 'monkeydo' + script_extension)
PACKAGER = os.path.join(CONNECT_IQ_SDK_DIR, 'bin', 'connectiqpkg' + script_extension)

BUILD_DIR = os.path.dirname(__file__)
PROGRAM_NAME = os.path.basename(BUILD_DIR)

RESOURCE_DIR = os.path.join(BUILD_DIR, 'resources')
SOURCE_DIR = os.path.join(BUILD_DIR, 'source')
BIN_DIR = os.path.join(BUILD_DIR, 'bin')

OUTPUT_FILENAME = os.path.join(BIN_DIR, PROGRAM_NAME + '.prg')
MANIFEST_FILE = os.path.join(BUILD_DIR, 'manifest.xml')


def print_command(cmd, title=''):
    print
    print title
    print '=' * 80
    print ' '.join(cmd)
    print '=' * 80
    print


def glob_tree(root, pattern=''):
    """Given a root directory and a function matching `pattern`,
    this will recursively search for files that match `pattern`"""
    return [os.path.join(dirpath, filename) 
            for dirpath, subdirs, filenames in os.walk(root)
                for filename in fnmatch.filter(filenames, pattern)]

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    
    parser.add_argument('-d', '--device', default=None, help='The id of the device to build for')
    parser.add_argument('--no-clean', action='store_true', help="Don't clean out the bin directory.")
    parser.add_argument('--no-sim', action='store_true', help="Don't run the simulator after compiling.")
    parser.add_argument('-r', '--release', action='store_true')
    parser.add_argument('-p', '--package', action='store_true', help='Run the packager')

    args = parser.parse_args()
    
    resources = [os.path.relpath(path) for path in glob_tree(RESOURCE_DIR, '*.xml')]
    sources = [os.path.relpath(path) for path in glob_tree(SOURCE_DIR, '*.mc')]

    # clean the bin dir first
    if not args.no_clean:
        to_clean = glob_tree(BIN_DIR, '*')
        for f in to_clean:
            print 'Removing', os.path.relpath(f)
            os.remove(f)

    # compile command
    cmd = [
        MONKEYC,
        '-o', os.path.relpath(OUTPUT_FILENAME),
        '-w',
        '-m', os.path.relpath(MANIFEST_FILE),
        '-z', ';'.join(resources),
    ]
    if args.device:
        cmd.append('-d')
        cmd.append(args.device)
    if args.release:
        cmd.append('-r')

    cmd.extend(sources)
    # compile things
    print_command(cmd, title='Compile Command')
    ret = subprocess.call(cmd)

    if not ret and args.package:
        cmd = [
            PACKAGER,
            '-o', '.',
            '-m', MANIFEST_FILE,
            '-n', PROGRAM_NAME,
            OUTPUT_FILENAME
        ]
        print_command(cmd, title='Package Command')
        subprocess.call(cmd)
    
    # if everything builds correctly, go ahead and try to push to the simulator
    if not ret and not args.no_sim and not args.package:
        cmd = [
            MONKEYDO,
            OUTPUT_FILENAME,
        ]
        if args.device:
            cmd.append(args.device)
        print_command(cmd, title='Simulator Command')
        subprocess.call(cmd)
