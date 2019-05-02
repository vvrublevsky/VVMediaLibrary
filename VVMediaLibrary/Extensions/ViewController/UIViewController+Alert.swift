//
//  UIViewController+Alert.swift
//  VVMediaLibrary
//
//  Created by Volodymyr Vrublevskyi on 5/2/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import UIKit

extension UIViewController {
    func presentAlert(_ title: String?, _ message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
