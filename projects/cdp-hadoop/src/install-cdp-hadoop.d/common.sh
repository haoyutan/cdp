#!/bin/bash


#-------------------------------------------------------------------------------
# Library functions
#-------------------------------------------------------------------------------
rc_add() {
    echo "$@" >>$CDP_RC
}

rc_apply() {
    rc_add "$@"
    eval "$@"
}

rc_contains() {
    local pattern="$1"
    grep -q "$pattern" $CDP_RC
}

rc_add_section_header() {
    local section_name="$1"
    rc_add ""
    rc_add "# $section_name configurations"
}

rc_contains_section() {
    local section_name="$1"
    rc_contains "# $section_name configurations"
}


install_package_to_opt() {
    local pkg_name=$1
    local pkg_short_name=$2

    local pkg_tar_ball=$MS_PROG_DIR/packages/$pkg_name.tar.gz
    if [ ! -e "$pkg_tar_ball" ]; then
        ms_logging_log "$pkg_tar_ball does not exist."
        return 1
    fi

    ms_logging_log "Extracting $MS_PROG_DIR/packages/$pkg_name.tar.gz..."
    local tmp_dir=$CDP_PREFIX/tmp/.extract/
    rm -rf $tmp_dir && mkdir -p $tmp_dir
    tar zxf $MS_PROG_DIR/packages/$pkg_name.tar.gz -C $tmp_dir
    local pkg_dir=`ls $tmp_dir | tail -1`
    rm -rf $CDP_PREFIX/opt/$pkg_dir
    mv $tmp_dir/$pkg_dir $CDP_PREFIX/opt/
    rm -rf $tmp_dir

    OLD_PWD=$(pwd)
    ms_logging_log "Creating symbolic link $CDP_PREFIX/opt/$pkg_short_name..."
    cd $CDP_PREFIX/opt/
    rm -rf $pkg_short_name && ln -s $pkg_dir $pkg_short_name
    cd $OLD_PWD
}


apply_cdp_m4_on_file() {
    local input_file="$1"
    local output_file="$2"
    ms_logging_log "Generating $output_file from $input_file..."
    cat $CDP_PREFIX/etc/cdp.m4 $input_file | m4 >$output_file
}


apply_cdp_m4_on_dir() {
    local input_dir="$1"
    local output_dir="$2"
    ms_logging_log "Generating files in $output_dir from $input_dir..."

    local input_files=$(ls $input_dir 2>/dev/null)
    if [ -z "$input_files" ]; then
        ms_debug_info "$input_dir does not contain any .m4 file."
        return 0
    fi

    local output_file=""
    for input_file in $input_files; do
        output_file=${input_file/%.m4/}
        if [ -e "$output_dir/$output_file" ]; then
            mv -f $output_dir/$output_file $output_dir/$output_file.orig
        fi
        apply_cdp_m4_on_file $input_dir/$input_file $output_dir/$output_file
    done
}


cdp_m4_add_definition() {
    local name="$1"
    local value="$2"
    local cdp_m4=$CDP_PREFIX/etc/cdp.m4
    local tmp_cdp_m4=$cdp_m4.tmp

    sed "s@divert(1)@define(\`$name', \`$value')@" $cdp_m4 >$tmp_cdp_m4
    printf "divert(1)" >>$tmp_cdp_m4
    mv -f $tmp_cdp_m4 $cdp_m4
}


test_installation()
{
    ms_logging_exec "$@"
}
#-------------------------------------------------------------------------------
