package com.campus.catalog;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/catalog")
public class CatalogController {

    @Autowired
    private CatalogRepository repository;

    @GetMapping
    public List<CatalogEvent> listAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Optional<CatalogEvent> getOne(@PathVariable Long id) {
        return repository.findById(id);
    }
}
