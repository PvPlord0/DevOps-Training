package com.campus.catalog.health;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> response = new HashMap<>();

        try {
            jdbcTemplate.execute("SELECT 1");
            response.put("status", "ok");
        } catch (Exception e) {
            response.put("status", "offline");
        }

        return response;
    }
}
