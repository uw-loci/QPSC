#!/usr/bin/env python3
"""
QPSC Repository Ecosystem Diagram

Generates a visual map of all QPSC repositories and their relationships,
including connections to external tools (Pycro-Manager, Micro-Manager, QuPath).

Run with: python qpsc_repo_tree.py
Output: qpsc_repo_tree.png and qpsc_repo_tree.svg
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

# -- Color palette ----------------------------------------------------------
C = {
    'qpsc_core':    '#2563EB',   # bright blue - main extension
    'qpsc_mod':     '#3B82F6',   # lighter blue - modality plugin
    'java_ext':     '#6366F1',   # indigo - other java extensions
    'python_pkg':   '#0D9488',   # teal - python packages
    'config':       '#16A34A',   # green - configuration
    'external':     '#EA580C',   # orange - external tools
    'hardware':     '#DC2626',   # red - hardware
    'analysis':     '#7C3AED',   # purple - analysis tools
    'bg':           '#F8FAFC',   # near-white background
    'group_qp':     '#EFF6FF',   # light blue group bg
    'group_py':     '#F0FDFA',   # light teal group bg
    'group_ext':    '#FFF7ED',   # light orange group bg
    'group_tool':   '#FAF5FF',   # light purple group bg
    'edge_data':    '#6B7280',   # gray for data flow
    'edge_dep':     '#1E40AF',   # dark blue for dependency
    'edge_ext':     '#C2410C',   # dark orange for external
}


def draw_box(ax, x, y, w, h, label, sublabel, color,
             fontsize=9, sublabel_size=7, bold=True, text_color='white'):
    """Draw a rounded rectangle node with label and optional sublabel."""
    box = FancyBboxPatch(
        (x - w/2, y - h/2), w, h,
        boxstyle="round,pad=0.08",
        facecolor=color, edgecolor='white', linewidth=1.5,
        zorder=3, alpha=0.95
    )
    ax.add_patch(box)

    weight = 'bold' if bold else 'normal'
    if sublabel:
        ax.text(x, y + 0.15, label, ha='center', va='center',
                fontsize=fontsize, fontweight=weight, color=text_color, zorder=4)
        ax.text(x, y - 0.2, sublabel, ha='center', va='center',
                fontsize=sublabel_size, color=text_color, alpha=0.85, zorder=4,
                style='italic')
    else:
        ax.text(x, y, label, ha='center', va='center',
                fontsize=fontsize, fontweight=weight, color=text_color, zorder=4)


def draw_group_box(ax, x, y, w, h, label, color, bg_color):
    """Draw a group/cluster background box with a label at the top."""
    box = FancyBboxPatch(
        (x - w/2, y - h/2), w, h,
        boxstyle="round,pad=0.15",
        facecolor=bg_color, edgecolor=color, linewidth=2,
        linestyle='--', zorder=1, alpha=0.5
    )
    ax.add_patch(box)
    ax.text(x, y + h/2 + 0.18, label, ha='center', va='bottom',
            fontsize=8.5, fontweight='bold', color=color, zorder=2,
            bbox=dict(boxstyle='round,pad=0.2', facecolor='white',
                      edgecolor=color, alpha=0.9, linewidth=1))


def draw_arrow(ax, x1, y1, x2, y2, color='#6B7280', style='-',
               width=1.5, label=None, label_offset=(0, 0.12),
               zorder=2, alpha=0.7):
    """Draw an arrow between two points."""
    ls = 'solid' if style == '-' else 'dashed'
    ax.annotate(
        '', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(
            arrowstyle='->', color=color, lw=width, linestyle=ls,
            alpha=alpha, shrinkA=8, shrinkB=8,
            connectionstyle='arc3,rad=0.0'
        ),
        zorder=zorder
    )
    if label:
        mx = (x1 + x2) / 2 + label_offset[0]
        my = (y1 + y2) / 2 + label_offset[1]
        ax.text(mx, my, label, ha='center', va='center',
                fontsize=6.5, color=color, alpha=0.9, zorder=zorder + 1,
                bbox=dict(boxstyle='round,pad=0.15', facecolor='white',
                          edgecolor='none', alpha=0.85))


def draw_curved_arrow(ax, x1, y1, x2, y2, color='#6B7280', rad=0.3,
                      width=1.5, label=None, style='-', alpha=0.7,
                      label_offset=(0, 0)):
    """Draw a curved arrow between two points."""
    ls = 'solid' if style == '-' else 'dashed'
    ax.annotate(
        '', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(
            arrowstyle='->', color=color, lw=width, linestyle=ls,
            alpha=alpha, shrinkA=8, shrinkB=8,
            connectionstyle=f'arc3,rad={rad}'
        ),
        zorder=2
    )
    if label:
        mx = (x1 + x2) / 2 + label_offset[0]
        my = (y1 + y2) / 2 + label_offset[1]
        ax.text(mx, my, label, ha='center', va='center',
                fontsize=6.5, color=color, alpha=0.9, zorder=3,
                bbox=dict(boxstyle='round,pad=0.15', facecolor='white',
                          edgecolor='none', alpha=0.85))


def create_repo_tree():
    fig, ax = plt.subplots(1, 1, figsize=(16, 12))
    fig.patch.set_facecolor(C['bg'])
    ax.set_facecolor(C['bg'])
    ax.set_xlim(-1.5, 15.5)
    ax.set_ylim(-1.5, 11.5)
    ax.set_aspect('equal')
    ax.axis('off')

    # Title
    ax.text(7, 11.0, 'QPSC Repository Ecosystem', ha='center', va='center',
            fontsize=20, fontweight='bold', color='#1E293B')
    ax.text(7, 10.55, 'uw-loci GitHub Organization + External Dependencies',
            ha='center', va='center', fontsize=11, color='#64748B', style='italic')

    # -- Node dimensions ----------------------------------------------------
    NW = 2.8   # node width
    NH = 0.72  # node height

    # -- Layout coordinates (x, y) ------------------------------------------
    # Row 0 (top): QuPath platform
    qupath_pos = (3.5, 9.6)

    # Row 1: Java extensions
    qpsc_pos   = (3.5, 7.9)
    ppm_pos    = (6.8, 7.9)
    t2p_pos    = (0.2, 7.9)

    # Row 2: Python packages (upper)
    server_pos = (3.5, 5.8)
    config_pos = (9.8, 5.8)

    # Row 3: Python packages (lower)
    ctrl_pos   = (6.8, 4.2)
    ppmlib_pos = (0.2, 4.2)

    # Row 4: External stack
    pycro_pos  = (6.8, 2.4)
    mm_pos     = (6.8, 0.8)
    hw_pos     = (10.0, 0.8)

    # Right column: Supporting tools
    dl_pos     = (13.0, 8.0)
    cluster_pos= (13.0, 6.4)
    ocr_pos    = (13.0, 4.8)

    # -- Group boxes --------------------------------------------------------
    # QuPath Extensions group
    draw_group_box(ax, 3.5, 7.9, 9.5, 1.2,
                   'QuPath Extensions (Java)', C['qpsc_core'], C['group_qp'])

    # Python Packages group
    draw_group_box(ax, 5.0, 4.8, 10.0, 3.2,
                   'Python Packages (pip)', C['python_pkg'], C['group_py'])

    # External / Hardware group
    draw_group_box(ax, 7.9, 1.3, 6.0, 1.8,
                   'Hardware Stack (External)', C['external'], C['group_ext'])

    # Analysis Tools group
    draw_group_box(ax, 13.0, 6.4, 3.2, 4.0,
                   'Supporting Tools', C['analysis'], C['group_tool'])

    # -- Draw nodes ---------------------------------------------------------
    # QuPath (external)
    draw_box(ax, *qupath_pos, NW, NH,
             'QuPath', 'qupath.github.io',
             C['external'], fontsize=10)

    # Core Java extensions
    draw_box(ax, *qpsc_pos, NW, NH,
             'qupath-extension-qpsc', 'Main extension',
             C['qpsc_core'], fontsize=8.5)

    draw_box(ax, *ppm_pos, NW, NH,
             'qupath-extension-ppm', 'PPM modality plugin',
             C['qpsc_mod'], fontsize=8.5)

    draw_box(ax, *t2p_pos, NW, NH,
             'extension-tiles-to-pyramid', 'Image stitching',
             C['java_ext'], fontsize=8)

    # Python packages
    draw_box(ax, *server_pos, NW, NH,
             'microscope_command_server', 'Socket server + workflows',
             C['python_pkg'], fontsize=8)

    draw_box(ax, *ctrl_pos, NW, NH,
             'microscope_control', 'Hardware abstraction',
             C['python_pkg'], fontsize=8.5)

    draw_box(ax, *ppmlib_pos, NW, NH,
             'ppm_library', 'Image processing',
             C['python_pkg'], fontsize=8.5)

    draw_box(ax, *config_pos, NW, NH,
             'microscope_configurations', 'YAML templates',
             C['config'], fontsize=8)

    # External stack
    draw_box(ax, *pycro_pos, NW, NH,
             'Pycro-Manager', 'Python-Java bridge',
             C['external'], fontsize=9)

    draw_box(ax, *mm_pos, NW, NH,
             'Micro-Manager', 'Device control',
             '#D35400', fontsize=9)

    draw_box(ax, *hw_pos, NW * 0.8, NH,
             'Microscope', 'Hardware',
             C['hardware'], fontsize=9)

    # Supporting tools
    draw_box(ax, *dl_pos, NW, NH,
             'extension-DL-pixel-classifier', 'Deep learning classification',
             C['analysis'], fontsize=7.5)

    draw_box(ax, *cluster_pos, NW, NH,
             'extension-pyclustering', 'Clustering + phenotyping',
             C['analysis'], fontsize=8)

    draw_box(ax, *ocr_pos, NW, NH,
             'extension-ocr4labels', 'Slide label OCR',
             C['analysis'], fontsize=8.5)

    # -- Draw edges ---------------------------------------------------------

    # QuPath -> QPSC (platform hosts extension)
    draw_arrow(ax, qupath_pos[0], qupath_pos[1] - NH/2,
               qpsc_pos[0], qpsc_pos[1] + NH/2,
               color=C['edge_dep'], width=2.5, label='hosts')

    # QPSC -> PPM (modality plugin)
    draw_arrow(ax, qpsc_pos[0] + NW/2, qpsc_pos[1],
               ppm_pos[0] - NW/2, ppm_pos[1],
               color=C['edge_dep'], width=2, label='modality plugin')

    # QPSC -> Tiles-to-Pyramid (dependency)
    draw_arrow(ax, qpsc_pos[0] - NW/2, qpsc_pos[1],
               t2p_pos[0] + NW/2, t2p_pos[1],
               color=C['edge_dep'], width=1.5, label='stitching',
               label_offset=(0, 0.18))

    # QPSC -> Server (socket commands -- the primary integration)
    draw_arrow(ax, qpsc_pos[0], qpsc_pos[1] - NH/2,
               server_pos[0], server_pos[1] + NH/2,
               color='#DC2626', width=3, label='TCP socket commands',
               alpha=0.85)

    # Server -> Control
    draw_arrow(ax, server_pos[0] + NW/2 - 0.2, server_pos[1] - NH/2 + 0.05,
               ctrl_pos[0] - NW/2 + 0.2, ctrl_pos[1] + NH/2 - 0.05,
               color=C['python_pkg'], width=1.5, label='hardware calls',
               label_offset=(0.15, 0.15))

    # Server -> PPM Library
    draw_arrow(ax, server_pos[0] - NW/2 + 0.2, server_pos[1] - NH/2 + 0.05,
               ppmlib_pos[0] + NW/2 - 0.2, ppmlib_pos[1] + NH/2 - 0.05,
               color=C['python_pkg'], width=1.5, label='image processing',
               label_offset=(-0.15, 0.15))

    # Config -> Server (dashed -- config loading)
    draw_arrow(ax, config_pos[0] - NW/2, config_pos[1],
               server_pos[0] + NW/2, server_pos[1],
               color=C['config'], width=1.2, style='--',
               label='YAML config', label_offset=(0, 0.18))

    # Config -> Control (dashed)
    draw_arrow(ax, config_pos[0] - 0.3, config_pos[1] - NH/2,
               ctrl_pos[0] + NW/2 - 0.1, ctrl_pos[1] + NH/2 - 0.05,
               color=C['config'], width=1.0, style='--')

    # Control -> Pycro-Manager
    draw_arrow(ax, ctrl_pos[0], ctrl_pos[1] - NH/2,
               pycro_pos[0], pycro_pos[1] + NH/2,
               color=C['edge_ext'], width=2, label='Python API')

    # Pycro-Manager -> Micro-Manager
    draw_arrow(ax, pycro_pos[0], pycro_pos[1] - NH/2,
               mm_pos[0], mm_pos[1] + NH/2,
               color=C['edge_ext'], width=2, label='Java bridge')

    # Micro-Manager -> Hardware
    draw_arrow(ax, mm_pos[0] + NW/2, mm_pos[1],
               hw_pos[0] - NW * 0.8/2, hw_pos[1],
               color=C['hardware'], width=2.5, label='device control')

    # PPM extension -> ppm_library (subprocess calls for analysis)
    draw_curved_arrow(ax,
                      ppm_pos[0] - 0.6, ppm_pos[1] - NH/2,
                      ppmlib_pos[0] + 0.8, ppmlib_pos[1] + NH/2,
                      color='#0891B2', width=1.5, rad=-0.25,
                      label='subprocess calls', style='--',
                      label_offset=(-0.9, 0.0))

    # Tiles-to-pyramid receives raw tiles from server
    draw_curved_arrow(ax,
                      server_pos[0] - NW/2, server_pos[1] + 0.15,
                      t2p_pos[0] + 0.2, t2p_pos[1] - NH/2,
                      color=C['edge_data'], width=1.2, rad=-0.35,
                      label='raw tiles', style='--',
                      label_offset=(-0.6, 0.4))

    # -- Legend -------------------------------------------------------------
    legend_x = -1.0
    legend_y = 2.2
    legend_items = [
        (C['qpsc_core'],   'QPSC Core Extension'),
        (C['qpsc_mod'],    'Modality Plugin'),
        (C['java_ext'],    'Java Extension'),
        (C['python_pkg'],  'Python Package'),
        (C['config'],      'Configuration'),
        (C['external'],    'External Tool'),
        (C['hardware'],    'Hardware'),
        (C['analysis'],    'Supporting Tool'),
    ]

    ax.text(legend_x, legend_y + 0.15, 'Legend', fontsize=9, fontweight='bold',
            color='#475569')
    for i, (color, label) in enumerate(legend_items):
        yy = legend_y - 0.32 * i - 0.25
        box = FancyBboxPatch((legend_x, yy - 0.1), 0.35, 0.22,
                             boxstyle="round,pad=0.02",
                             facecolor=color, edgecolor='white',
                             linewidth=0.5, zorder=5, alpha=0.9)
        ax.add_patch(box)
        ax.text(legend_x + 0.5, yy, label, fontsize=7.5, va='center',
                color='#334155')

    # Edge legend
    edge_legend_y = legend_y - len(legend_items) * 0.32 - 0.5
    ax.text(legend_x, edge_legend_y + 0.15, 'Connections', fontsize=9,
            fontweight='bold', color='#475569')
    edge_items = [
        ('#DC2626', '-',  'Socket communication'),
        (C['edge_dep'], '-',  'Dependency'),
        (C['edge_data'], '--', 'Data flow'),
    ]
    for i, (color, style, label) in enumerate(edge_items):
        yy = edge_legend_y - 0.32 * i - 0.25
        ls = 'solid' if style == '-' else 'dashed'
        ax.plot([legend_x, legend_x + 0.35], [yy, yy],
                color=color, linewidth=2.5, linestyle=ls, alpha=0.8)
        ax.text(legend_x + 0.5, yy, label, fontsize=7.5, va='center',
                color='#334155')

    # Footer note
    ax.text(7, -1.1,
            'Blue/teal nodes: github.com/uw-loci/*   |   '
            'Orange nodes: External open-source projects',
            ha='center', va='center', fontsize=8.5, color='#94A3B8',
            style='italic')

    plt.tight_layout(pad=0.5)
    return fig


if __name__ == '__main__':
    import os

    output_dir = os.path.dirname(os.path.abspath(__file__))
    fig = create_repo_tree()

    # Save PNG (high DPI for crisp rendering)
    png_path = os.path.join(output_dir, 'qpsc_repo_tree.png')
    fig.savefig(png_path, dpi=200, bbox_inches='tight',
                facecolor=fig.get_facecolor(), edgecolor='none')
    print(f"Saved: {png_path}")

    # Save SVG
    svg_path = os.path.join(output_dir, 'qpsc_repo_tree.svg')
    fig.savefig(svg_path, format='svg', bbox_inches='tight',
                facecolor=fig.get_facecolor(), edgecolor='none')
    print(f"Saved: {svg_path}")

    plt.close(fig)
    print("Done!")
