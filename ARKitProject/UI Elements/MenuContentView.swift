//
//  MenuContentView.swift
//  ARKitProject
//
//  Created by Zhou, James on 2024/11/14.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import UIKit

@objc
protocol MenuContentViewDelegate {
    @objc
    func menuContentView(contentView: MenuContentView, didSelectAt index: Int)
}

class CardTableViewCell: UITableViewCell {
    
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 10
        cardView.layer.masksToBounds = true
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 5
        cardView.backgroundColor = .white
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 1
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .gray
        
        contentView.backgroundColor = UIColor(hex: "f5f5f5")
        
        contentView.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(descriptionLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            descriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            descriptionLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -15)
        ])
    }
    
    func configure(title: String, description: String) {
        titleLabel.text = title
        descriptionLabel.text = description
    }
}

class MenuContentView: UIView {
    
    var delegate: MenuContentViewDelegate?
    var data: [(String, String)]? {
        didSet {
            menuTableView.reloadData()
        }
    }
    
    private let identifer: String = "CardCell"
    
    lazy var menuTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(CardTableViewCell.classForCoder(), forCellReuseIdentifier: identifer)
        tableView.backgroundColor = UIColor(hex: "#f5f5f5")
        return tableView
    }()
    
    lazy var headerLogoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "mobilebytesLogo"))
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubview()
        setupConstraint()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubview()
        setupConstraint()
    }
    
    func setupSubview() {
        addSubview(headerLogoImageView)
        addSubview(menuTableView)
    }
    
    func setupConstraint() {
        NSLayoutConstraint.activate([
            headerLogoImageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            headerLogoImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            headerLogoImageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            headerLogoImageView.heightAnchor.constraint(equalToConstant: 150),
            
            menuTableView.topAnchor.constraint(equalTo: headerLogoImageView.bottomAnchor, constant: 0),
            menuTableView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            menuTableView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            menuTableView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }
}

extension MenuContentView: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: identifer, for: indexPath) as! CardTableViewCell
        if let item = data?[indexPath.row] {
            cell.configure(title: item.0, description: item.1)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let validateDelegate = delegate {
            validateDelegate.menuContentView(contentView: self, didSelectAt: indexPath.row)
        }
        
    }
}
