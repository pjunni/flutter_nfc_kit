import os

# Set the paths to the directories containing the Dart and Kotlin files
dart_dir = '../lib'
kotlin_dir = '../android/src/main/kotlin/im/nfc/flutter_nfc_kit'

# Set the path to the output file
output_file = 'all_flutter_nfc_kit_files.txt'

# Open the output file in write mode
with open(output_file, 'w') as f:
    # Traverse the Dart directory and write the contents of each file to the output file
    for filename in os.listdir(dart_dir):
        if filename.endswith('.dart'):
            with open(os.path.join(dart_dir, filename), 'r') as dart_file:
                f.write(f"Contents of file {filename}:\n")
                f.write(dart_file.read())
                f.write('\n\n')

    # Traverse the Kotlin directory and write the contents of each file to the output file
    for filename in os.listdir(kotlin_dir):
        if filename.endswith('.kt'):
            with open(os.path.join(kotlin_dir, filename), 'r') as kotlin_file:
                f.write(f"Contents of file {filename}:\n")
                f.write(kotlin_file.read())
                f.write('\n\n')

print(f"All Dart and Kotlin files have been written to {output_file}")