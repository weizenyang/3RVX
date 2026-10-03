// Threshold slope / step ramp
// ---------------------------------------------------------------------------
// Footprint 723 x 120 mm, 46 mm tall at the back, sloping down across the
// 120 mm (short) direction to a thin toe at the open front edge.
//
// Three sides sit against walls: the left end, the right end and the back
// (high) edge. On each wall side the solid body is held back from the wall by
// `wall_clearance`, and a thin top lip overhangs past the nominal wall line by
// `scribe_allowance`. Trim / sand that lip to follow the uneven wall. The lip
// has a 45 degree chamfer underneath, so nothing needs support.
//
// 723 mm will not fit a printer bed, so the ramp is cut into `segments`
// pieces joined by glued bow-tie keys (underside) plus two alignment pins
// per joint that keep the walking surfaces flush.
//
// Coordinates: X = along the 723 mm length, Y = front (low) -> back wall,
// Z = up. Every part prints in the orientation it is exported in, flat base
// down, no supports.
// ---------------------------------------------------------------------------

/* [Size (mm)] */
// Wall-to-wall length. Use the SMALLEST measurement you took.
opening_length = 723;
// Open front edge to the back wall.
depth = 120;
// Height at the back wall (the step you are ramping up to).
height = 46;
// Thickness of the low front edge. Below ~1.5 mm it chips and curls.
toe = 2;

/* [Fit to uneven walls] */
fit_left = true;
fit_right = true;
fit_back = true;
// Body is held this far off each wall (room for bulges / bad plaster).
wall_clearance = 3;
// Lip sticks out this far PAST the nominal wall line. Trim it to the wall.
scribe_allowance = 3;
// Lip thickness at its outer edge (chamfered at 45 deg underneath).
lip_thickness = 4;

/* [Printing] */
// 3 -> ~243 mm parts (250 mm+ beds), 4 -> ~183 mm parts (220 mm beds).
segments = 3;
// What to output.
part = "assembly"; // [assembly, segment, key, pin, hardware_plate]
// Which segment when part = "segment" (0 = left end).
segment_index = 0;

/* [Joints] */
key_length = 30;   // across the joint
key_width = 22;    // wide ends of the bow-tie
key_neck = 12;     // narrow middle (sits on the joint line)
key_height = 8;
key_fit = 0.2;     // clearance per side in the pocket
pin_d = 6;         // printed pin, or a 6 mm dowel / M6 rod
pin_fit = 0.4;     // extra hole diameter
pin_depth = 15;    // hole depth into each segment

/* [Preview] */
show_walls = true;   // ghost walls in the assembly view
explode = 0;         // gap between segments in the assembly view

/* [Grip] */
grooves = true;
groove_pitch = 10; // measured along the slope
groove_width = 3;
groove_depth = 1;

/* [Hidden] */
$fn = 40;
eps = 0.01;

lip_out = wall_clearance + scribe_allowance;       // lip reach beyond body face
chamfer_band = lip_thickness + lip_out;            // lip depth where it meets the body
y_body = depth - (fit_back ? wall_clearance : 0);  // body back face = top of slope
y_max = fit_back ? depth + scribe_allowance : y_body;
x_body0 = fit_left ? wall_clearance : 0;
x_body1 = opening_length - (fit_right ? wall_clearance : 0);
x_min = fit_left ? -scribe_allowance : 0;
x_max = opening_length + (fit_right ? scribe_allowance : 0);
k = (height - toe) / y_body;                       // rise per mm of run
slope_angle = atan(k);

function top(y) = min(toe + k * y, height);
function joint_x(i) = x_min + i * (x_max - x_min) / segments;

// Keys must leave >= 5 mm of plastic above the pocket at their front edge.
key_y_min = (key_height + 0.4 + 5 - toe) / k + key_width / 2 + key_fit;
key_y_max = y_body - key_width / 2 - 6;
key_ys = [key_y_min, key_y_max];
pin_ys = [(key_y_min + key_y_max) / 2, y_body - pin_d / 2 - 6];
pin_yz = [for (y = pin_ys) [y, top(y) / 2]];

groove_y0 = (5 - toe) / k + groove_width;
groove_y1 = y_body - groove_width - 2;
groove_ys = [for (y = [groove_y0 : groove_pitch * cos(slope_angle) : groove_y1]) y];

assert(key_y_min < key_y_max - key_width, "Ramp too low/short for two keys: reduce key_height or key_width");
assert(lip_thickness + groove_depth < height, "lip_thickness too large");

// ---- building blocks ------------------------------------------------------

// Map a 2D (y, z) profile to a prism running along X from x0 to x1.
module along_x(x0, x1)
  multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1]])
    translate([0, 0, x0]) linear_extrude(x1 - x0) children();

// Bounded half-space z >= a*x + b*y + c.
module above_plane(a, b, c, size = 3000)
  multmatrix([[1, 0, 0, 0], [0, 1, 0, 0], [a, b, 1, c], [0, 0, 0, 1]])
    translate([-size / 2, -size / 2, 0]) cube(size);

// Cross-section of the ramp in the Y-Z plane, including the back scribe lip.
module profile() {
  difference() {
    union() {
      polygon([[0, 0], [y_body, 0], [y_body, height], [0, toe]]);
      if (fit_back)
        polygon([[y_body, height - chamfer_band], [y_max, height - lip_thickness],
                 [y_max, height], [y_body, height]]);
    }
    if (grooves)
      for (y = groove_ys)
        translate([y, top(y)]) rotate(slope_angle)
          square([groove_width, 2 * groove_depth], center = true);
  }
}

// Scribe lip on an end wall: same top surface as the ramp, underside rising at
// 45 deg from the body face out to the lip edge. Because the top is "slope,
// then flat", the region under it is the union of two half-spaces.
module end_lip(left) {
  dir = left ? -1 : 1;
  face = left ? x_body0 : -x_body1;
  intersection() {
    if (left) along_x(x_min, x_body0 + eps) profile();
    else along_x(x_body1 - eps, x_max) profile();
    union() {
      above_plane(dir, k, toe - chamfer_band + face);
      above_plane(dir, 0, height - chamfer_band + face);
    }
  }
}

module envelope() {
  along_x(x_body0, x_body1) profile();
  if (fit_left) end_lip(true);
  if (fit_right) end_lip(false);
}

module bowtie()
  polygon([[-key_length / 2, -key_width / 2], [0, -key_neck / 2],
           [key_length / 2, -key_width / 2], [key_length / 2, key_width / 2],
           [0, key_neck / 2], [-key_length / 2, key_width / 2]]);

// Circle with a 45 deg point on top so a horizontal hole prints without support.
module teardrop(r)
  union() {
    circle(r);
    polygon([[-r * cos(45), r * sin(45)], [r * cos(45), r * sin(45)], [0, r * sqrt(2)]]);
  }

module joint_cuts(xj) {
  for (yk = key_ys)
    translate([xj, yk, -1]) linear_extrude(key_height + 0.4 + 1) offset(delta = key_fit) bowtie();
  for (p = pin_yz)
    along_x(xj - pin_depth, xj + pin_depth) translate(p) teardrop((pin_d + pin_fit) / 2);
}

module segment(i) {
  xa = i == 0 ? x_min - 1 : joint_x(i);
  xb = i == segments - 1 ? x_max + 1 : joint_x(i + 1);
  difference() {
    intersection() {
      envelope();
      translate([xa, -1, -1]) cube([xb - xa, y_max + 2, height + 2]);
    }
    for (j = [i, i + 1]) if (j > 0 && j < segments) joint_cuts(joint_x(j));
  }
}

module key() linear_extrude(key_height) bowtie();

// Lies along X with a flat underneath so it prints on its side (layers run
// along the pin, the strong way for shear at the joint). The flat is deep
// enough that no part of the round underside overhangs more than 45 deg.
module pin() {
  len = 2 * pin_depth - 1;
  c = 0.6;  // end chamfer
  flat = pin_d / 2 * (1 - cos(45)) + 0.05;
  intersection() {
    translate([0, 0, pin_d / 2 - flat]) rotate([0, 90, 0]) union() {
      cylinder(d1 = pin_d - 2 * c, d2 = pin_d, h = c);
      translate([0, 0, c]) cylinder(d = pin_d, h = len - 2 * c);
      translate([0, 0, len - c]) cylinder(d1 = pin_d, d2 = pin_d - 2 * c, h = c);
    }
    translate([-1, -pin_d, 0]) cube([len + 2, 2 * pin_d, pin_d]);
  }
}

module hardware_plate() {
  n = segments - 1;  // joints
  for (j = [0 : n - 1], kk = [0 : 1])
    translate([(j * 2 + kk) * (key_length + 6), 0, 0]) key();
  for (j = [0 : n - 1], kk = [0 : 1])
    translate([(j * 2 + kk) * (2 * pin_depth + 5) - key_length / 2, key_width / 2 + 8, 0]) pin();
}

module walls_ghost() {
  t = 15;
  h = height + 40;
  color([0.6, 0.6, 0.6, 0.25]) {
    if (fit_left) translate([-t, 0, 0]) cube([t, depth + t, h]);
    if (fit_right) translate([opening_length, 0, 0]) cube([t, depth + t, h]);
    if (fit_back) translate([-t, depth, 0]) cube([opening_length + 2 * t, t, h]);
  }
}

module assembly() {
  palette = [[0.90, 0.45, 0.15], [0.20, 0.55, 0.80], [0.35, 0.70, 0.35], [0.80, 0.70, 0.20], [0.6, 0.4, 0.8]];
  for (i = [0 : segments - 1])
    color(palette[i % len(palette)]) translate([i * explode, 0, 0]) segment(i);
  for (j = [1 : segments - 1], yk = key_ys)
    color("black") translate([joint_x(j) + (j - 0.5) * explode, yk, 0.2 - explode]) key();
  if (show_walls && explode == 0) walls_ghost();
}

// ---- output ---------------------------------------------------------------

if (part == "assembly") assembly();
else if (part == "segment")
  translate([-(segment_index == 0 ? x_min : joint_x(segment_index)), 0, 0]) segment(segment_index);
else if (part == "key") key();
else if (part == "pin") pin();
else if (part == "hardware_plate") hardware_plate();
