#!/usr/bin/env python3
"""
QPSC System Architecture Diagrams
Generates both detailed and simplified architecture views

Run with: python qpsc_architecture.py
Output: DOT files and PNG images (if graphviz binary is installed)
"""

from graphviz import Digraph
import os

# Color scheme
COLORS = {
    'qupath_blue': '#4A90D9',
    'qupath_light': '#7AB8F5',
    'python_dark': '#306998',
    'python_light': '#4A7DB8',
    'pycromanager': '#E67E22',
    'micromanager': '#D35400',
    'hardware': '#C0392B',
    'config': '#27AE60',
    'data': '#9B59B6',
    'user': '#3498DB',
}


def create_complete_architecture():
    """
    Create the complete QPSC architecture diagram showing all components,
    packages, and their interactions.
    """
    dot = Digraph('QPSC_Complete_Architecture',
                  comment='QPSC Complete System Architecture')
    dot.attr(rankdir='TB', compound='true', splines='ortho', nodesep='0.5', ranksep='0.6')
    dot.attr('node', shape='box', style='rounded,filled', fontname='Helvetica', fontsize='11')
    dot.attr('edge', fontname='Helvetica', fontsize='9')

    # ===========================================
    # USER LAYER
    # ===========================================
    with dot.subgraph(name='cluster_user') as user:
        user.attr(label='User', style='filled', fillcolor='#EBF5FB',
                  color='#3498DB', fontsize='12', fontname='Helvetica Bold')
        user.node('researcher', 'Researcher / Pathologist\n(Define ROIs, Configure Acquisition)',
                  fillcolor=COLORS['user'], fontcolor='white')

    # ===========================================
    # QUPATH ECOSYSTEM
    # ===========================================
    with dot.subgraph(name='cluster_qupath') as qp:
        qp.attr(label='QuPath Ecosystem (Java)', style='filled', fillcolor='#E8F4FD',
                color=COLORS['qupath_blue'], fontsize='12', fontname='Helvetica Bold')

        # QuPath Core
        with qp.subgraph(name='cluster_qp_core') as core:
            core.attr(label='QuPath Core', style='dashed', color='#4A90D9')
            core.node('qp_app', 'QuPath Application',
                      fillcolor=COLORS['qupath_blue'], fontcolor='white')
            core.node('qp_viewer', 'Image Viewer\n& Annotations',
                      fillcolor=COLORS['qupath_blue'], fontcolor='white')
            core.node('qp_project', 'Project System',
                      fillcolor=COLORS['qupath_blue'], fontcolor='white')

        # QPSC Extension
        with qp.subgraph(name='cluster_qpsc') as qpsc:
            qpsc.attr(label='qupath-extension-qpsc', style='filled',
                      fillcolor='#D4E8FC', color='#4A90D9')
            qpsc.node('qpsc_controller', 'Workflow Controllers\n(BoundingBox, ExistingImage,\nAlignment)',
                      fillcolor='#5DA5E8', fontcolor='white')
            qpsc.node('qpsc_modality', 'Modality System\n(PPM, Brightfield, etc.)',
                      fillcolor='#5DA5E8', fontcolor='white')
            qpsc.node('qpsc_socket', 'Socket Client\n(TCP Communication)',
                      fillcolor='#5DA5E8', fontcolor='white')
            qpsc.node('qpsc_utils', 'Utilities\n(Config, Tiling,\nCoordinates)',
                      fillcolor='#5DA5E8', fontcolor='white')

        # Tiles to Pyramid
        qp.node('t2p', 'qupath-extension-\ntiles-to-pyramid\n(Stitching)',
                fillcolor=COLORS['qupath_light'], fontcolor='white')

    # ===========================================
    # PYTHON MICROSCOPE CONTROL (Modular Packages)
    # ===========================================
    with dot.subgraph(name='cluster_python') as py:
        py.attr(label='Python Microscope Control (pip packages)', style='filled',
                fillcolor='#E8F0F8', color=COLORS['python_dark'],
                fontsize='12', fontname='Helvetica Bold')

        # microscope_command_server
        with py.subgraph(name='cluster_server') as srv:
            srv.attr(label='microscope-command-server', style='filled',
                     fillcolor='#D4E4F4', color='#306998')
            srv.node('srv_socket', 'Socket Server\n(TCP/IP)',
                     fillcolor=COLORS['python_dark'], fontcolor='white')
            srv.node('srv_workflow', 'Acquisition Workflows\n(Orchestration)',
                     fillcolor=COLORS['python_dark'], fontcolor='white')
            srv.node('srv_pipeline', 'Processing Pipeline',
                     fillcolor=COLORS['python_dark'], fontcolor='white')

        # microscope_control
        with py.subgraph(name='cluster_control') as ctrl:
            ctrl.attr(label='microscope-control', style='filled',
                      fillcolor='#D4E4F4', color='#306998')
            ctrl.node('ctrl_hw', 'Hardware Abstraction\n(Stage, Camera)',
                      fillcolor=COLORS['python_light'], fontcolor='white')
            ctrl.node('ctrl_af', 'Autofocus System\n(Algorithms, Metrics)',
                      fillcolor=COLORS['python_light'], fontcolor='white')
            ctrl.node('ctrl_tissue', 'Tissue Detection\n(Empty Region Skip)',
                      fillcolor=COLORS['python_light'], fontcolor='white')
            ctrl.node('ctrl_config', 'Config Manager\n(YAML Loading)',
                      fillcolor=COLORS['python_light'], fontcolor='white')

        # ppm_library
        with py.subgraph(name='cluster_ppm') as ppm:
            ppm.attr(label='ppm-library', style='filled',
                     fillcolor='#D4E4F4', color='#306998')
            ppm.node('ppm_cal', 'PPM Calibration\n(Polarizer, Hue-to-Angle)',
                     fillcolor=COLORS['python_light'], fontcolor='white')
            ppm.node('ppm_debayer', 'Debayering\n(CPU/GPU)',
                     fillcolor=COLORS['python_light'], fontcolor='white')
            ppm.node('ppm_imaging', 'Image Processing\n(Background, Correction)',
                     fillcolor=COLORS['python_light'], fontcolor='white')
            ppm.node('ppm_analysis', 'Analysis Workflows\n(Fiber Angles)',
                     fillcolor=COLORS['python_light'], fontcolor='white')

        # microscope_configurations
        with py.subgraph(name='cluster_configs') as cfg:
            cfg.attr(label='microscope-configurations', style='filled',
                     fillcolor='#E8F8E8', color='#27AE60')
            cfg.node('cfg_templates', 'YAML Templates\n(config, autofocus,\nimageprocessing)',
                     fillcolor=COLORS['config'], fontcolor='white')
            cfg.node('cfg_resources', 'Hardware Resources\n(LOCI Lookup Tables)',
                     fillcolor=COLORS['config'], fontcolor='white')

    # ===========================================
    # MICRO-MANAGER STACK
    # ===========================================
    with dot.subgraph(name='cluster_mm') as mm:
        mm.attr(label='Micro-Manager Stack', style='filled', fillcolor='#FDF2E8',
                color=COLORS['pycromanager'], fontsize='12', fontname='Helvetica Bold')
        mm.node('pycromanager', 'Pycro-Manager\n(Python-Java Bridge)',
                fillcolor=COLORS['pycromanager'], fontcolor='white')
        mm.node('micromanager', 'Micro-Manager\n(Device Adapters)',
                fillcolor=COLORS['micromanager'], fontcolor='white')
        mm.node('mmcore', 'MMCore API',
                fillcolor=COLORS['micromanager'], fontcolor='white')

    # ===========================================
    # HARDWARE
    # ===========================================
    with dot.subgraph(name='cluster_hw') as hw:
        hw.attr(label='Microscope Hardware', style='filled', fillcolor='#FDEDEC',
                color=COLORS['hardware'], fontsize='12', fontname='Helvetica Bold')
        hw.node('hw_stage', 'XYZ Stage',
                fillcolor=COLORS['hardware'], fontcolor='white')
        hw.node('hw_camera', 'Camera',
                fillcolor=COLORS['hardware'], fontcolor='white')
        hw.node('hw_optics', 'Optics\n(Polarizers, Objectives,\nIllumination)',
                fillcolor=COLORS['hardware'], fontcolor='white')

    # ===========================================
    # DATA OUTPUT
    # ===========================================
    with dot.subgraph(name='cluster_data') as data:
        data.attr(label='Data Output', style='filled', fillcolor='#F4ECF7',
                  color=COLORS['data'], fontsize='12', fontname='Helvetica Bold')
        data.node('data_tiles', 'Raw Tiles\n(OME-TIFF)',
                  fillcolor=COLORS['data'], fontcolor='white')
        data.node('data_pyramid', 'Pyramidal Images\n(OME-ZARR / OME-TIFF)',
                  fillcolor=COLORS['data'], fontcolor='white')

    # ===========================================
    # EDGES - User Flow
    # ===========================================
    dot.edge('researcher', 'qp_viewer', label='Draw ROIs')

    # QuPath internal
    dot.edge('qp_app', 'qp_viewer')
    dot.edge('qp_app', 'qp_project')
    dot.edge('qp_viewer', 'qpsc_controller', label='ROI Bounds')

    # QPSC internal
    dot.edge('qpsc_controller', 'qpsc_modality')
    dot.edge('qpsc_controller', 'qpsc_socket')
    dot.edge('qpsc_controller', 'qpsc_utils')
    dot.edge('qpsc_modality', 'qpsc_socket')

    # ===========================================
    # EDGES - Socket Communication (KEY!)
    # ===========================================
    dot.edge('qpsc_socket', 'srv_socket',
             label='TCP Socket\nCommands', color='#E74C3C', penwidth='2.5', style='bold')

    # ===========================================
    # EDGES - Python Server Internal
    # ===========================================
    dot.edge('srv_socket', 'srv_workflow')
    dot.edge('srv_workflow', 'srv_pipeline')
    dot.edge('srv_workflow', 'ctrl_hw')
    dot.edge('srv_workflow', 'ctrl_af')
    dot.edge('srv_pipeline', 'ppm_debayer')
    dot.edge('srv_pipeline', 'ppm_imaging')

    # Control package internal
    dot.edge('ctrl_af', 'ctrl_tissue')
    dot.edge('ctrl_config', 'cfg_templates', style='dashed')
    dot.edge('cfg_templates', 'cfg_resources', style='dashed', label='references')

    # PPM package internal
    dot.edge('ppm_cal', 'ppm_analysis')

    # ===========================================
    # EDGES - Hardware Control Chain
    # ===========================================
    dot.edge('ctrl_hw', 'pycromanager', label='Python API')
    dot.edge('pycromanager', 'micromanager', label='Java Bridge')
    dot.edge('micromanager', 'mmcore')
    dot.edge('mmcore', 'hw_stage')
    dot.edge('mmcore', 'hw_camera')
    dot.edge('mmcore', 'hw_optics')

    # ===========================================
    # EDGES - Data Flow
    # ===========================================
    dot.edge('hw_camera', 'data_tiles', label='Capture', style='dashed')
    dot.edge('data_tiles', 't2p', label='Stitch')
    dot.edge('t2p', 'data_pyramid')
    dot.edge('data_pyramid', 'qp_project', label='Import')

    # Feedback loop
    dot.edge('qp_project', 'qp_viewer', style='dashed',
             label='Iterative\nAcquisition', color='#27AE60')

    return dot


def create_simplified_slide():
    """
    Create a simplified diagram suitable for presentations to general audiences.
    Emphasizes the software-driven acquisition and processing workflow.
    """
    dot = Digraph('QPSC_Simplified', comment='QPSC - Software-Driven Microscopy')
    dot.attr(rankdir='LR', splines='polyline', nodesep='0.8', ranksep='1.2')
    dot.attr('node', shape='box', style='rounded,filled', fontname='Helvetica',
             fontsize='14', width='2', height='0.8')
    dot.attr('edge', fontname='Helvetica', fontsize='11', penwidth='2')

    # Main flow nodes
    dot.node('user', 'Researcher\nDefines Regions',
             fillcolor='#3498DB', fontcolor='white', shape='ellipse')

    dot.node('qupath', 'QuPath\n+ QPSC Extension\n(Annotation & Control)',
             fillcolor='#4A90D9', fontcolor='white')

    dot.node('python', 'Python Server\n(Acquisition &\nProcessing)',
             fillcolor='#306998', fontcolor='white')

    dot.node('micromanager', 'Micro-Manager\n(Hardware Control)',
             fillcolor='#E67E22', fontcolor='white')

    dot.node('microscope', 'Automated\nMicroscope',
             fillcolor='#C0392B', fontcolor='white', shape='box3d')

    dot.node('output', 'High-Resolution\nImages',
             fillcolor='#9B59B6', fontcolor='white', shape='folder')

    # Main forward flow
    dot.edge('user', 'qupath', label='1. Draw ROIs', color='#2C3E50')
    dot.edge('qupath', 'python', label='2. Send Commands', color='#2C3E50')
    dot.edge('python', 'micromanager', label='3. Control', color='#2C3E50')
    dot.edge('micromanager', 'microscope', label='4. Move & Capture', color='#2C3E50')

    # Return flow
    dot.edge('microscope', 'python', label='5. Images', style='dashed',
             color='#7F8C8D', constraint='false')
    dot.edge('python', 'output', label='6. Process & Stitch', style='dashed',
             color='#7F8C8D')
    dot.edge('output', 'qupath', label='7. Import Results', style='dashed',
             color='#7F8C8D', constraint='false')

    # Iterative loop
    dot.edge('qupath', 'user', label='8. Refine & Repeat',
             style='dotted', color='#27AE60', constraint='false')

    return dot


def create_single_slide_compact():
    """
    Create an ultra-compact diagram for a single presentation slide.
    Maximum clarity, minimum detail.
    """
    dot = Digraph('QPSC_Slide', comment='QPSC Overview')
    dot.attr(rankdir='LR', splines='spline', nodesep='1', ranksep='1.5',
             bgcolor='transparent')
    dot.attr('node', shape='box', style='rounded,filled,bold', fontname='Helvetica Bold',
             fontsize='16', width='2.2', height='1')
    dot.attr('edge', fontname='Helvetica', fontsize='12', penwidth='3')

    # Three main components
    dot.node('annotate', 'QuPath\nAnnotate\nRegions',
             fillcolor='#4A90D9', fontcolor='white')

    dot.node('acquire', 'Automated\nAcquisition\n& Processing',
             fillcolor='#306998', fontcolor='white')

    dot.node('analyze', 'High-Res\nImages for\nAnalysis',
             fillcolor='#9B59B6', fontcolor='white')

    # Flow
    dot.edge('annotate', 'acquire', label='Software\nControls\nMicroscope',
             color='#E74C3C', fontcolor='#E74C3C')
    dot.edge('acquire', 'analyze', label='Stitched\nPyramidal\nImages',
             color='#27AE60', fontcolor='#27AE60')

    # Loop back
    dot.edge('analyze', 'annotate', label='Iterative\nRefinement',
             style='dashed', color='#7F8C8D', constraint='false')

    return dot


if __name__ == '__main__':
    # Output directory
    output_dir = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(output_dir, exist_ok=True)

    diagrams = [
        ('qpsc_architecture_complete', create_complete_architecture()),
        ('qpsc_architecture_simplified', create_simplified_slide()),
        ('qpsc_architecture_slide', create_single_slide_compact()),
    ]

    for name, diagram in diagrams:
        filepath = os.path.join(output_dir, name)

        # Save DOT source
        diagram.save(filepath + '.dot')
        print(f"Saved: {filepath}.dot")

        # Try to render PNG
        try:
            diagram.render(filepath, format='png', cleanup=True)
            print(f"Rendered: {filepath}.png")
        except Exception as e:
            print(f"Note: Could not render PNG for {name} (graphviz binary not installed)")

        # Also render SVG (often looks better)
        try:
            diagram.render(filepath, format='svg', cleanup=False)
            print(f"Rendered: {filepath}.svg")
        except Exception:
            pass

    print("\n" + "="*60)
    print("DOT files can be rendered online at:")
    print("  https://dreampuf.github.io/GraphvizOnline/")
    print("  https://edotor.net/")
    print("="*60)
