import csv
import argparse
import sys
from PIL import Image


field_frame_name = "Name"
field_delay = "Delay(1/60)"
field_sprite_name = "File Name"
field_x = "X"
field_y = "Y"
field_width = "Width"
field_height = "Height"


def slice_to_bitplanes(img, x_start, y):
    """
    Converts an 8-pixel slice of the image into two bitplanes.
    """
    plane_0 = 0
    plane_1 = 0
    for bit in range(8):
        (r, g, b, a) = img.getpixel((x_start + bit, y))
        shift = 7 - bit
        if a == 0:
            continue
        elif r == 255:
            plane_0 |= 1 << shift
        elif r == 0:
            plane_0 |= 1 << shift
            plane_1 |= 1 << shift
        else:
            plane_1 |= 1 << shift
    return plane_0, plane_1


def region_to_binary(img, x, y, w, h):
    """
    Converts a region of the image into data suitable for TIQuest's renderer.
    """
    w_bytes = (w + 7) // 8

    out = []

    for row in range(h):
        plane_0_row = []
        plane_1_row = []
        for byte in range(w_bytes):
            x_start = x + byte * 8
            plane_0_slice, plane_1_slice = slice_to_bitplanes(img, x_start, y + row)
            plane_0_row.append(plane_0_slice)
            plane_1_row.append(plane_1_slice)
        out += plane_0_row
        out += plane_1_row
    
    return out


def fix_frame_size(frames):
    """
    Corrects for a bug in GraphicsGale where the frame dimensions are not specified correctly in the layout csv.
    """
    # Copy the values from the first frame into all frames.
    # Assumes that all frames have the same dimensions and that the dimensions of the first frame are
    # actually correct.
    w = frames[0][field_width]
    h = frames[0][field_height]
    for f in frames:
        f[field_width] = w
        f[field_height] = h


def parse_frame_map(csvfile):
    """
    Loads the layout of the sprite frames from a csv file.
    """
    reader = csv.DictReader(csvfile, [field_frame_name, field_delay, field_sprite_name, field_x, field_y, field_width, field_height])
    reader.__next__()   # Skip header row
    frames = list(reader)
    fix_frame_size(frames)
    return frames


def frame_to_string(img, frame):
    """
    Converts a single frame into a string which can be included in TIQuest.
    """
    # Parse frame name
    suffix_start = frame[field_sprite_name].index(".")
    full_name = frame[field_sprite_name][:suffix_start] + "_" + frame[field_frame_name]

    # Parse image region
    data = region_to_binary(img, int(frame[field_x]), int(frame[field_y]), int(frame[field_width]), int(frame[field_height]))
    data_str = ",".join([str(d) for d in data])

    return (
        f"{full_name}_delay .equ {frame[field_delay]}\n"
        f"{full_name}: .db {data_str}\n"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Converts .png images into include files for TIQuest.")
    parser.add_argument(
        "-i", "--image",
        nargs=1,
        required=True,
        type=argparse.FileType(mode="rb"),
        help="Path to the input image.")
    parser.add_argument(
        "-m", "--map",
        nargs=1,
        required=True,
        type=argparse.FileType(mode="r"),
        help="Path to a csv file containing information on how the frames are laid out.")
    parser.add_argument(
        "-o", "--out",
        nargs=1,
        required=True,
        type=argparse.FileType(mode="w", encoding="utf-8"),
        help="Output .inc file")

    args = parser.parse_args(sys.argv[1:])

    img = Image.open(args.image[0]).convert("RGBA")
    frames = parse_frame_map(args.map[0])
    out_content = "\n".join([frame_to_string(img, f) for f in frames])
    args.out[0].write(out_content)
    
    args.image[0].close()
    args.map[0].close()
    args.out[0].close()
