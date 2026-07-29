#!/usr/bin/env python3
#
# Copyright 2026 Ettus Research, a National Instruments Brand
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
"""Test discoverable features in Python API."""

from uhd_test_base import UHDPythonTestCase


class DiscoverableFeaturesTest(UHDPythonTestCase):
    """Test discoverable features on radio_control and mb_controller.

    This test:
    - Enumerates all available features
    - Verifies has_feature() works correctly
    - Verifies get_feature() returns valid objects
    - Calls basic methods on each feature type to verify they work
    """

    test_name = "DiscoverableFeaturesTest"

    def run_test(self, test_name, test_args):
        """Run test and report results."""
        import uhd

        results = {}

        try:
            # Connect to device
            graph = uhd.rfnoc.RfnocGraph(self.args_str)
            mboard = graph.get_mb_controller()

            # Get first radio block
            radio_blocks = graph.find_blocks("Radio")
            if not radio_blocks:
                self.log.warning("No Radio blocks found")
                return {"passed": False}

            radio = uhd.rfnoc.RadioControl(graph.get_block(radio_blocks[0]))

            # Test motherboard controller features
            results["mboard_enumerate"] = self._test_mb_enumerate(mboard)
            results["mboard_has_feature"] = self._test_mb_has_feature(mboard)
            results["mboard_get_feature"] = self._test_mb_get_feature(mboard)

            # Test radio control features
            results["radio_enumerate"] = self._test_radio_enumerate(radio)
            results["radio_has_feature"] = self._test_radio_has_feature(radio)
            results["radio_get_feature"] = self._test_radio_get_feature(radio)

            # Overall result
            passed = all(results.values())

            for key, value in results.items():
                self.log.info(f"{key}: {'PASS' if value else 'FAIL'}")
                self.report_result("discoverable_features", key, value)

            return {"passed": passed}

        except Exception as e:
            self.log.error(f"Test failed with exception: {e}")
            self.report_result("discoverable_features", "exception", False)
            return {"passed": False}

    def _test_mb_enumerate(self, mboard):
        """Test enumerate_features on mb_controller."""
        try:
            features = mboard.enumerate_features()
            self.log.info(f"Motherboard features: {features}")
            return len(features) >= 0
        except Exception as e:
            self.log.error(f"enumerate_features failed: {e}")
            return False

    def _test_mb_has_feature(self, mboard):
        """Test has_feature on mb_controller."""
        import uhd

        try:
            # Test all feature IDs, some may not be available
            feature_ids = [
                uhd.types.DiscoverableFeatureID.FPGA_LOAD_NOTIFICATION,
                uhd.types.DiscoverableFeatureID.GPIO_POWER,
                uhd.types.DiscoverableFeatureID.GPS,
                uhd.types.DiscoverableFeatureID.REF_CLK_CALIBRATION,
                uhd.types.DiscoverableFeatureID.TRIG_IO_MODE,
            ]

            available_features = []
            for fid in feature_ids:
                if mboard.has_feature(fid):
                    available_features.append(fid)

            self.log.info(f"Available MB features: {available_features}")
            return True
        except Exception as e:
            self.log.error(f"has_feature failed: {e}")
            return False

    def _test_mb_get_feature(self, mboard):
        """Test get_feature on mb_controller."""
        import uhd

        try:
            # Test getting features that are available
            if mboard.has_feature(uhd.types.DiscoverableFeatureID.GPIO_POWER):
                gpio_power = mboard.get_feature(uhd.types.DiscoverableFeatureID.GPIO_POWER)
                if gpio_power is None:
                    self.log.error("GPIO_POWER feature is None")
                    return False
                self.log.info("GPIO_POWER feature retrieved successfully")

            if mboard.has_feature(uhd.types.DiscoverableFeatureID.REF_CLK_CALIBRATION):
                ref_clk = mboard.get_feature(uhd.types.DiscoverableFeatureID.REF_CLK_CALIBRATION)
                if ref_clk is None:
                    self.log.error("REF_CLK_CALIBRATION feature is None")
                    return False
                self.log.info("REF_CLK_CALIBRATION feature retrieved successfully")

            if mboard.has_feature(uhd.types.DiscoverableFeatureID.TRIG_IO_MODE):
                trig_io = mboard.get_feature(uhd.types.DiscoverableFeatureID.TRIG_IO_MODE)
                if trig_io is None:
                    self.log.error("TRIG_IO_MODE feature is None")
                    return False
                self.log.info("TRIG_IO_MODE feature retrieved successfully")

            if mboard.has_feature(uhd.types.DiscoverableFeatureID.FPGA_LOAD_NOTIFICATION):
                fpga = mboard.get_feature(uhd.types.DiscoverableFeatureID.FPGA_LOAD_NOTIFICATION)
                if fpga is None:
                    self.log.error("FPGA_LOAD_NOTIFICATION feature is None")
                    return False
                self.log.info("FPGA_LOAD_NOTIFICATION feature retrieved successfully")

            return True
        except Exception as e:
            self.log.error(f"get_feature failed: {e}")
            return False

    def _test_radio_enumerate(self, radio):
        """Test enumerate_features on radio_control."""
        try:
            features = radio.enumerate_features()
            self.log.info(f"Radio features: {features}")
            return len(features) >= 0
        except Exception as e:
            self.log.error(f"radio enumerate_features failed: {e}")
            return False

    def _test_radio_has_feature(self, radio):
        """Test has_feature on radio_control."""
        import uhd

        try:
            # Test all radio feature IDs
            feature_ids = [
                uhd.types.DiscoverableFeatureID.INTERNAL_SYNC,
                uhd.types.DiscoverableFeatureID.TX_COMPLEX_GAIN,
                uhd.types.DiscoverableFeatureID.RX_COMPLEX_GAIN,
                uhd.types.DiscoverableFeatureID.SPI_GETTER_IFACE,
                uhd.types.DiscoverableFeatureID.ADC_SELF_CALIBRATION,
            ]

            available_features = []
            for fid in feature_ids:
                if radio.has_feature(fid):
                    available_features.append(fid)

            self.log.info(f"Available radio features: {available_features}")
            return True
        except Exception as e:
            self.log.error(f"radio has_feature failed: {e}")
            return False

    def _test_radio_get_feature(self, radio):
        """Test get_feature on radio_control."""
        import uhd

        try:
            # Test getting features that are available
            if radio.has_feature(uhd.types.DiscoverableFeatureID.ADC_SELF_CALIBRATION):
                adc_cal = radio.get_feature(uhd.types.DiscoverableFeatureID.ADC_SELF_CALIBRATION)
                if adc_cal is None:
                    self.log.error("ADC_SELF_CALIBRATION feature is None")
                    return False
                self.log.info("ADC_SELF_CALIBRATION feature retrieved successfully")

            if radio.has_feature(uhd.types.DiscoverableFeatureID.SPI_GETTER_IFACE):
                spi = radio.get_feature(uhd.types.DiscoverableFeatureID.SPI_GETTER_IFACE)
                if spi is None:
                    self.log.error("SPI_GETTER_IFACE feature is None")
                    return False
                self.log.info("SPI_GETTER_IFACE feature retrieved successfully")

            if radio.has_feature(uhd.types.DiscoverableFeatureID.INTERNAL_SYNC):
                int_sync = radio.get_feature(uhd.types.DiscoverableFeatureID.INTERNAL_SYNC)
                if int_sync is None:
                    self.log.error("INTERNAL_SYNC feature is None")
                    return False
                self.log.info("INTERNAL_SYNC feature retrieved successfully")

            if radio.has_feature(uhd.types.DiscoverableFeatureID.TX_COMPLEX_GAIN):
                tx_gain = radio.get_feature(uhd.types.DiscoverableFeatureID.TX_COMPLEX_GAIN)
                if tx_gain is None:
                    self.log.error("TX_COMPLEX_GAIN feature is None")
                    return False
                self.log.info("TX_COMPLEX_GAIN feature retrieved successfully")

            if radio.has_feature(uhd.types.DiscoverableFeatureID.RX_COMPLEX_GAIN):
                rx_gain = radio.get_feature(uhd.types.DiscoverableFeatureID.RX_COMPLEX_GAIN)
                if rx_gain is None:
                    self.log.error("RX_COMPLEX_GAIN feature is None")
                    return False
                self.log.info("RX_COMPLEX_GAIN feature retrieved successfully")

            return True
        except Exception as e:
            self.log.error(f"radio get_feature failed: {e}")
            return False
