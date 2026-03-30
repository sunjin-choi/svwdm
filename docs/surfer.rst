Surfer Waveform Viewing
=======================

This page describes how Surfer is used in this repository, including the repo-local launcher, command files, saved state files, and mapping translators.

.. contents::
   :local:

Overview
--------

Surfer is the preferred waveform viewer for this repo when it is installed on your machine. The existing ``make wave-<simulation_name>`` targets still work; they now launch the repo-local wrapper in ``scripts/open_wave_surfer.sh`` when ``surfer`` is available on ``PATH``.

The wrapper provides three useful behaviors:

*   It keeps the existing CMake ``wave-*`` flow unchanged.
*   It loads a repo-local ``.sucl`` command file for the simulation on first open.
*   It prefers a saved ``.ron`` state file for that simulation once you have customized and saved the layout.

The repo-local Surfer assets live under ``.surfer/``:

*   ``default.sucl``: fallback startup commands for any waveform
*   ``<simulation_name>.sucl``: startup view for a specific simulation
*   ``mappings/*.map``: enum and state translators for common tuner buses
*   ``<simulation_name>.ron``: optional saved layout for a specific simulation

Quick Start
-----------

1.  Make sure ``surfer`` is installed and available on ``PATH``.
2.  Source the project environment:

    .. code-block:: bash

       source sourceme.sh

3.  Open a waveform from the repo root:

    .. code-block:: bash

       scripts/wave.sh tuner_search_row

    This refreshes the CMake build tree and then wraps:

    .. code-block:: bash

       cmake -S . -B build
       cmake --build build --target wave-tuner_search_row

4.  On first open, the wrapper loads ``.surfer/tuner_search_row.sucl``.
5.  If you customize the layout, save it from Surfer as ``.surfer/tuner_search_row.ron``.
6.  On future opens, the wrapper uses the ``.ron`` state file instead of the ``.sucl`` startup script.

You can also launch the wrapper directly:

.. code-block:: bash

   scripts/open_wave_surfer.sh build/sim/tuner_search_row/waveform.vcd

Repo Workflow
-------------

The normal usage flow in this repo is:

1.  Run ``source sourceme.sh``.
2.  Open the waveform with ``scripts/wave.sh <simulation_name>``.
3.  Adjust formatting or grouping inside Surfer if needed.
4.  Save the session as ``.surfer/<simulation_name>.ron`` if you want a persistent view for that simulation.

If ``surfer`` is not installed, ``sourceme.sh`` falls back to ``gtkwave`` if it is available.

Command Files And Saved State
-----------------------------

Surfer supports both startup command files and saved state files.

In this repo:

*   ``.sucl`` files are used to create an initial focused view for each simulation.
*   ``.ron`` files are used for a user-curated persistent layout.

The wrapper selects files in this order:

1.  ``.surfer/<simulation_name>.ron``
2.  ``.surfer/<simulation_name>.sucl``
3.  ``.surfer/default.sucl``

That means the ``.sucl`` file acts as the default, while the ``.ron`` file becomes authoritative after you save a session.

Useful CLI Forms
----------------

Surfer is primarily a GUI waveform viewer, but it has useful command-line startup options:

.. code-block:: bash

   surfer waveform.vcd
   surfer -c .surfer/tuner_search_row.sucl build/sim/tuner_search_row/waveform.vcd
   surfer -s .surfer/tuner_search_row.ron build/sim/tuner_search_row/waveform.vcd

The ``-c`` option loads a command file after the waveform opens. The ``-s`` option loads a saved state file.

Surfer also exposes an in-app command prompt and supports the same commands in ``.sucl`` files. In this repo, the command files mainly use:

*   ``scope_add_as_group``
*   ``divider_add``
*   ``preference_set_hierarchy_style Tree``
*   ``variable_force_name_type Unique``
*   ``zoom_fit``

Mappings
--------

Project-local mappings live in ``.surfer/mappings/``. These make common state buses easier to read in the format picker.

The current mappings are:

*   ``search_state``
*   ``lock_state``
*   ``detect_state``
*   ``detect_if_state``
*   ``ctrl_arb_state``
*   ``ctrl_arb_if_state``

These are intended for buses driven by the tuner packages in ``lib/verilog/tuner/``.

Recommended usage:

1.  Add the relevant state bus to the waveform view.
2.  Change its display format in Surfer to the matching mapping name.
3.  Save the session as ``.ron`` if you want that formatting to persist.

Headless And Remote Use
-----------------------

Surfer has a headless server mode, and the Surfer project also provides a separate server binary called ``surver``. That is useful when the waveform file is large and you want to browse it remotely instead of copying it locally.

This repo does not currently wrap ``surver`` automatically. The local integration here is focused on opening locally generated waveforms from the existing ``make wave-*`` targets.

Troubleshooting
---------------

If ``make wave-<simulation_name>`` does not open Surfer:

*   Check that ``surfer`` is installed and visible on ``PATH``.
*   Re-run ``source sourceme.sh`` in the shell you use for building.
*   Make sure the CMake build tree already exists under ``build/``.
*   Prefer ``scripts/wave.sh <simulation_name>`` over calling ``cmake --build`` directly, because it refreshes cached viewer settings in the build tree.
*   Check the value of ``WAVEFORM_VIEWER``:

    .. code-block:: bash

       echo "$WAVEFORM_VIEWER"

*   If you need a custom binary location, set ``SURFER_BIN`` before launching:

    .. code-block:: bash

       export SURFER_BIN=/path/to/surfer
       scripts/wave.sh tuner_search_row

*   If a saved ``.ron`` view becomes stale, remove it and the wrapper will fall back to the ``.sucl`` file.

References
----------

Current official Surfer references:

*   https://docs.surfer-project.org/book/
*   https://docs.surfer-project.org/book/commands/index.html
*   https://docs.surfer-project.org/book/plugins/mapping.html
*   https://docs.surfer-project.org/book/remote.html
