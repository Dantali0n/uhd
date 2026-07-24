//
// Copyright 2026 Ettus Research, a National Instruments Brand
//
// SPDX-License-Identifier: GPL-3.0-or-later
//

#ifndef INCLUDED_UHD_FEATURES_PYTHON_HPP
#define INCLUDED_UHD_FEATURES_PYTHON_HPP

#include <uhd/features/discoverable_feature.hpp>
#include <uhd/features/spi_getter_iface.hpp>

void export_discoverable_feature(py::module& m)
{
    using discoverable_feature = uhd::features::discoverable_feature;
    using feature_id_t         = discoverable_feature::feature_id_t;

    py::enum_<feature_id_t>(m, "discoverable_feature_id")
        .value("RESERVED0", feature_id_t::RESERVED0)
        .value("RESERVED1", feature_id_t::RESERVED1)
        .value("FPGA_LOAD_NOTIFICATION", feature_id_t::FPGA_LOAD_NOTIFICATION)
        .value("ADC_SELF_CALIBRATION", feature_id_t::ADC_SELF_CALIBRATION)
        .value("REF_CLK_CALIBRATION", feature_id_t::REF_CLK_CALIBRATION)
        .value("TRIG_IO_MODE", feature_id_t::TRIG_IO_MODE)
        .value("GPIO_POWER", feature_id_t::GPIO_POWER)
        .value("SPI_GETTER_IFACE", feature_id_t::SPI_GETTER_IFACE)
        .value("INTERNAL_SYNC", feature_id_t::INTERNAL_SYNC)
        .value("GPS", feature_id_t::GPS)
        .value("TX_COMPLEX_GAIN", feature_id_t::TX_COMPLEX_GAIN)
        .value("RX_COMPLEX_GAIN", feature_id_t::RX_COMPLEX_GAIN);

    py::class_<uhd::features::spi_periph_config_t>(m, "spi_periph_config")
        .def(py::init<>())
        .def_readwrite("periph_cs", &uhd::features::spi_periph_config_t::periph_cs)
        .def_readwrite("periph_sdi", &uhd::features::spi_periph_config_t::periph_sdi)
        .def_readwrite("periph_sdo", &uhd::features::spi_periph_config_t::periph_sdo)
        .def_readwrite("periph_clk", &uhd::features::spi_periph_config_t::periph_clk);
}

#endif // INCLUDED_UHD_FEATURES_PYTHON_HPP
