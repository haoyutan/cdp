#!/bin/bash


main() {
    ms_import ini
    ms_import target

    local packages_dir="$1"
    if [ -z "$packages_dir" ]; then
        ms_print_usage -p $MS_PROG "PACKAGES_DIR" and_die
    fi

    local packages_ini="$packages_dir/.packages.ini"
    if [ ! -f "$packages_ini" ]; then
        ms_die "Cannot find $packages_ini."
    fi

    local package_name="$2"

    ms_ini_parse $packages_ini cdp_packages

    if [ -z "$package_name" ]; then
        ms_output_block begin "Download all $CDP_META_DIST_NAME packages."
        cdp_packages_default
        for pkg in ${cdp_packages[*]}; do
            cdp_packages_$pkg
            ms_target_task_run "Downloading $cdp_fn..." \
                "curl -o $packages_dir/$cdp_fn $cdp_url" \
                "test ! -e $packages_dir/$cdp_fn"
        done
        ms_output_block end
    else
        cdp_packages_$package_name
        ms_target_task_run "Downloading $cdp_fn..." \
            "curl -o $packages_dir/$cdp_fn $cdp_url" \
            "test ! -e $packages_dir/$cdp_fn"
    fi
}
